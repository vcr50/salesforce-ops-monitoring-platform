# Streaming Telemetry — Fallback Polling Strategy (Milestone 48D)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Design — Pending Review  
**Version**: 1.0  
**Depends on**: [LWC empApi Subscription Design (48C)](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/streaming-telemetry-lwc-subscription-design.md)

---

## 1. Overview

While real-time streaming telemetry via Platform Events drastically reduces latency and database load, it relies on client-side WebSocket connections (CometD protocol). WebSockets are susceptible to transport interruptions caused by network drops, browser sleep cycles, corporate firewalls, and Salesforce Platform Event hourly quotas.

To guarantee that the Command Center remains functional, we design an **adaptive, hybrid polling strategy**. This strategy treats streaming as a high-performance enhancement layer and keeps a background polling timer as a bulletproof safety net. 

### Core Design Rules
1. **Never completely disable polling**: The background timer runs continuously.
2. **Adaptive Polling Intervals**:
   - **60 seconds** when streaming is healthy and active.
   - **30 seconds** (original behavior) when streaming is unavailable, disconnected, or failing.
3. **Automatic recovery**: If streaming goes offline and later recovers, the polling interval shifts back to the conservative 60-second limit.

---

## 2. Adaptive Polling Architecture

The following diagram illustrates how the LWC component coordinates the state of `isStreamingActive` with the execution timer to dynamically adjust its polling speed:

```
                  ┌─────────────────────────────────────┐
                  │          LWC Initialization         │
                  └──────────────────┬──────────────────┘
                                     │
                        _subscribeToStreaming()
                                     │
                    Is CometD streaming active?
                     /                         \
                   YES                          NO
                   /                             \
      ┌─────────────────────────┐    ┌─────────────────────────┐
      │ isStreamingActive = true │    │isStreamingActive = false│
      │   Poll Interval = 60s   │    │   Poll Interval = 30s   │
      └────────────┬────────────┘    └────────────┬────────────┘
                   │                              │
                   │                              │
         [Incoming Event]                [CometD Error fired]
                   │                              │
            refreshApex()                         │
                   │                     ┌────────▼────────┐
         [Timeout reached]               │Revert Poll: 30s │
                   │                     └────────┬────────┘
             refreshApex()                        │
                   │                     [Retry Stream: 30s]
                   ▼                              ▼
```

---

## 3. Dynamic Interval Switching Design

To dynamically change the polling interval in a vanilla JavaScript/LWC environment, a single `setInterval` call is not sufficient because its delay cannot be changed after creation. Instead, we use recursive `setTimeout` or dynamically reconstruct the `setInterval` timer when the connection state transitions.

We choose the **timer reconstruction pattern** (`_resetPollingInterval()`) because it is clean, predictable, and integrates seamlessly with LWC lifecycle hooks.

### 3.1 Properties and Constants

```javascript
// Constants (for fallback-polling-design)
const ACTIVE_STREAM_POLL_MS = 60000;  // 60 seconds when streaming is active
const FALLBACK_ONLY_POLL_MS = 30000;  // 30 seconds when streaming is down
const STREAM_RETRY_INTERVAL_MS = 30000; // Retry streaming subscription every 30s if down

// Tracked properties in LWC class:
isStreamingActive = false;
_pollTimerHandle;
_retryTimerHandle;
```

### 3.2 Dynamic Timer Implementation Code

```javascript
/**
 * Starts the adaptive polling timer. Reconstructs the timer based on the current
 * value of `isStreamingActive`.
 */
_startAdaptivePolling() {
    // 1. Clear any existing timer to avoid duplicate concurrent threads
    this._stopAdaptivePolling();
    
    // 2. Select appropriate interval
    const currentInterval = this.isStreamingActive 
        ? ACTIVE_STREAM_POLL_MS 
        : FALLBACK_ONLY_POLL_MS;
        
    console.log(`[ZentomDashboard] Starting adaptive polling at ${currentInterval / 1000}s interval.`);
    
    // 3. Establish the polling cycle
    this._pollTimerHandle = setInterval(() => {
        this._executeFallbackRefresh();
    }, currentInterval);
}

/**
 * Stop the polling cycle.
 */
_stopAdaptivePolling() {
    if (this._pollTimerHandle) {
        clearInterval(this._pollTimerHandle);
        this._pollTimerHandle = null;
    }
}

/**
 * Triggered by the polling timer. Invokes refreshApex() to refresh the cache.
 */
_executeFallbackRefresh() {
    console.log(`[ZentomDashboard] Fallback polling refresh executed. Stream active: ${this.isStreamingActive}`);
    if (this.wiredDashboard) {
        refreshApex(this.wiredDashboard)
            .then(() => {
                this.lastRefreshed = new Date();
            })
            .catch(error => {
                console.error('[ZentomDashboard] Fallback refresh error:', error);
            });
    }
}
```

---

## 4. Connection State Transitions

The system shifts state when the streaming channel reports connection success or failure:

### 4.1 Transition 1: Stream Connect Success
- **Trigger**: First successful event received on CometD channel, or the CometD subscription callback completes successfully.
- **Action**: 
  1. Set `this.isStreamingActive = true`.
  2. Call `this._startAdaptivePolling()` (this automatically cancels the 30-second interval and provisions the 60-second interval).
  3. Cancel any pending stream reconnection retry timers.

```javascript
handleStreamingConnectSuccess() {
    if (!this.isStreamingActive) {
        console.log('[ZentomDashboard] Streaming connection verified active. Shifting polling to 60s.');
        this.isStreamingActive = true;
        this._startAdaptivePolling();
    }
    
    // Clear reconnection timer if active
    if (this._retryTimerHandle) {
        clearTimeout(this._retryTimerHandle);
        this._retryTimerHandle = null;
    }
}
```

### 4.2 Transition 2: Stream Connection Failure (Drop / Limit Exceeded)
- **Trigger**: LWC `onError` callback fires, or subscription fails in the promise catch block.
- **Action**:
  1. Set `this.isStreamingActive = false`.
  2. Call `this._startAdaptivePolling()` (automatically cancels the 60-second interval and provisions the 30-second interval).
  3. Schedule a reconnection retry timer (e.g., attempt to re-subscribe after 30 seconds).

```javascript
handleStreamingDisconnect(error) {
    if (this.isStreamingActive) {
        console.warn('[ZentomDashboard] Streaming disconnected/failed. Reverting polling to 30s.', error);
        this.isStreamingActive = false;
        this._startAdaptivePolling();
    }
    
    // Schedule stream subscription retry if not already scheduled
    if (!this._retryTimerHandle) {
        console.log('[ZentomDashboard] Scheduling stream subscription retry in 30 seconds...');
        this._retryTimerHandle = setTimeout(() => {
            this._retryTimerHandle = null;
            this._retryStreamingSubscription();
        }, STREAM_RETRY_INTERVAL_MS);
    }
}
```

---

## 5. Streaming Reconnection Logic

When disconnected, the component attempts to re-establish the CometD connection gracefully without requiring a full page reload:

```javascript
_retryStreamingSubscription() {
    console.log('[ZentomDashboard] Attempting to reconnect streaming channels...');
    
    // Clean up old subscriptions first
    this._cleanupSubscriptions();
    
    // Re-subscribe
    this._subscribeToStreamingChannels();
}

_cleanupSubscriptions() {
    if (this._dashboardSubscription) {
        unsubscribeFromChannel(this._dashboardSubscription)
            .catch(() => {});
        this._dashboardSubscription = null;
    }
    if (this._integrationSubscription) {
        unsubscribeFromChannel(this._integrationSubscription)
            .catch(() => {});
        this._integrationSubscription = null;
    }
}
```

---

## 6. Cleanup & Lifecycle Checklist

To prevent memory leaks and background API queries, all timers and active retry triggers must be thoroughly deleted inside `disconnectedCallback()`:

```javascript
disconnectedCallback() {
    console.log('[ZentomDashboard] Unmounting. Tearing down all timers and subscriptions.');
    
    // 1. Unsubscribe from channels
    this._cleanupSubscriptions();
    
    // 2. Clear polling interval timer
    this._stopAdaptivePolling();
    
    // 3. Clear reconnection retry timer
    if (this._retryTimerHandle) {
        clearTimeout(this._retryTimerHandle);
        this._retryTimerHandle = null;
    }
}
```

---

## 7. Verification & Safety Scenarios

| Testing Scenario | Action | Expected Output | Safety Layer |
|---|---|---|---|
| **Scenario 1**: Normal Setup | Load Dashboard | Subscription connects -> `isStreamingActive = true` -> Polling runs at 60s | Extended interval reduces database load immediately |
| **Scenario 2**: Connection Drops | Disable network connection briefly | `onError` fires -> `isStreamingActive = false` -> Polling runs at 30s | Standard 30s polling handles data refresh |
| **Scenario 3**: Network Recovers | Re-enable network connection | Retry timer fires -> subscription succeeds -> `isStreamingActive = true` -> Polling runs at 60s | Reconnection logic automatically scales back |
| **Scenario 4**: Platform Event Limits Exceeded | Exceed daily event quota in org | Subscription catch block intercepts -> degrades to 30s polling | Transparent fallback, operator experiences zero UI interruption |

---

## 8. Implementation Checklist for Milestone 48D

- [ ] Add `isStreamingActive` property to `zentomDashboard.js`
- [ ] Add `_pollTimerHandle` and `_retryTimerHandle` properties
- [ ] Replace `setInterval` polling in `connectedCallback` with `_startAdaptivePolling()`
- [ ] Implement `handleStreamingConnectSuccess()`, `handleStreamingDisconnect()`, and reconnection retry timers
- [ ] Update `disconnectedCallback` to cleanly cancel all interval and timeout timers
