# Streaming Telemetry — LWC empApi Subscription Design (Milestone 48C)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Design — Pending Review  
**Version**: 1.0  
**Depends on**: [Platform Event Contract Design (48B)](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/streaming-telemetry-platform-event-contract.md)

---

## 1. Overview

This document details the frontend implementation design for subscribing to real-time events on the SentinelFlow Command Center. It covers the creation of a reusable LWC utility module `streamingTelemetry` and the integration of `lightning/empApi` subscriptions into the `zentomDashboard` LWC dashboard controller.

This design introduces a **2-second debounce mechanism** to handle high-frequency events gracefully, supports subscription to multiple event channels (both the new `SentinelFlow_Dashboard_Event__e` and the existing `Integration_Health_Event__e`), and sets up hook points for the adaptive fallback polling strategy (detailed in 48D).

---

## 2. Reusable Utility Module Design (`streamingTelemetry.js`)

To keep LWC controllers modular and avoid duplicate CometD boilerplate, we design a shared JavaScript utility. Although Salesforce LWC does not support traditional service classes easily, a lightweight utility module (LWC without HTML) works perfectly.

### 2.1 Module API Specifications

The utility module will export functions to handle:
1. Subscription registration
2. Unsubscription cleanup
3. Global CometD error listeners
4. Reusable event debouncing

### 2.2 Proposed Implementation Code (`force-app/main/default/lwc/streamingTelemetry/streamingTelemetry.js`)

```javascript
/**
 * TomCodeX Engineering — SentinelFlow
 * Reusable LWC streaming telemetry utility using lightning/empApi.
 */
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

/**
 * Subscribes to a given Platform Event channel with a callback.
 * 
 * @param {string} channelName - The CometD channel name (e.g., '/event/SentinelFlow_Dashboard_Event__e')
 * @param {number} replayId - The replay ID strategy (-1 for latest only)
 * @param {function} onEventCallback - Callback triggered when an event is received
 * @returns {Promise<object>} - Resolves to the subscription object
 */
export function subscribeToChannel(channelName, replayId = -1, onEventCallback) {
    return subscribe(channelName, replayId, (response) => {
        if (onEventCallback) {
            onEventCallback(response);
        }
    })
    .then((subscription) => {
        console.log(`[StreamingTelemetry] Subscribed to channel: ${channelName}`);
        return subscription;
    })
    .catch((error) => {
        console.error(`[StreamingTelemetry] Failed to subscribe to ${channelName}:`, error);
        throw error;
    });
}

/**
 * Unsubscribes from an active subscription.
 * 
 * @param {object} subscription - The active subscription object returned from subscribeToChannel
 * @returns {Promise<void>}
 */
export function unsubscribeFromChannel(subscription) {
    return new Promise((resolve, reject) => {
        if (!subscription) {
            resolve();
            return;
        }
        
        unsubscribe(subscription, (response) => {
            console.log('[StreamingTelemetry] Unsubscribed successfully:', response);
            resolve();
        });
    });
}

/**
 * Registers a global error handler for empApi transport failures.
 * 
 * @param {function} onErrorCallback - Callback triggered when a streaming transport error occurs
 */
export function registerErrorHandler(onErrorCallback) {
    onError((error) => {
        console.error('[StreamingTelemetry] CometD connection/transport error received:', error);
        if (onErrorCallback) {
            onErrorCallback(error);
        }
    });
}

/**
 * Creates a debounced version of a function that delays its execution
 * until after wait milliseconds have elapsed since the last time it was called.
 * 
 * @param {function} func - The function to debounce
 * @param {number} wait - The debounce timeout in milliseconds
 * @returns {function} - The debounced function wrapper
 */
export function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}
```

---

## 3. Dashboard LWC Integration Design (`zentomDashboard.js`)

The `zentomDashboard` LWC will act as the orchestrator. It will import the `streamingTelemetry` utility functions, establish real-time subscriptions, and refresh the dashboard data using `refreshApex()`.

### 3.1 Import Modifications

We will add imports for the `streamingTelemetry` utility and `lightning/platformShowToastEvent`:

```javascript
import { 
    subscribeToChannel, 
    unsubscribeFromChannel, 
    registerErrorHandler, 
    debounce 
} from 'c/streamingTelemetry';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
```

### 3.2 Property Additions

To track state, subscription handles, and telemetry status:

```javascript
// Add inside the ZentomDashboard class:
_dashboardSubscription;
_integrationSubscription;
isStreamingActive = false;
```

---

## 4. Debounce and Event Handling Design

### 4.1 Debounce Window Selection

During active periods, Salesforce triggers may generate multiple Platform Events in a rapid sequence (e.g., an incident is created, immediately analyzed by Zentom AI, and a high risk score causes a transition to `Pending Approval`). This creates 3 events (`INCIDENT_CREATED`, `AI_TRACE_UPDATED`, `APPROVAL_REQUIRED`) in less than 500 milliseconds.

To prevent:
1. Executing 3 back-to-back heavy Apex SOQL updates on the client
2. Page lag due to rapid rerendering
3. Salesforce rate-limit consumption

We implement a **2-second (2000 ms) debounce window**. Any event received within 2 seconds of a previous event restarts the timer.

### 4.2 Selective vs. Full Refresh

For Phase 1, any valid incoming event will trigger a full, debounced `refreshApex(this.wiredDashboard)`. 

However, we can display a subtle, elegant toast notification for operators when specific high-priority events are received (e.g. critical incident created, approval requested). This provides immediate visual value without forcing separate queries.

### 4.3 Debounced Event Callback Implementation

```javascript
// Debounced refresh handler defined in LWC class:
debouncedRefresh = debounce(() => {
    console.log('[ZentomDashboard] Debounced telemetry refresh triggering...');
    if (this.wiredDashboard) {
        refreshApex(this.wiredDashboard)
            .then(() => {
                this.lastRefreshed = new Date();
                console.log('[ZentomDashboard] Telemetry-driven refresh complete.');
            })
            .catch(error => {
                console.error('[ZentomDashboard] Telemetry-driven refresh failed:', error);
            });
    }
}, 2000);

// Unified Event Router
handleIncomingTelemetryEvent(response) {
    const payload = response.data.payload;
    console.log('[ZentomDashboard] Incoming telemetry event:', payload.Event_Type__c, payload);
    
    // 1. Trigger the debounced dashboard data refresh
    this.debouncedRefresh();
    
    // 2. Display real-time toast alert to operator for high-priority events
    this.processEventToasts(payload);
}

processEventToasts(payload) {
    const eventType = payload.Event_Type__c;
    const incidentNumber = payload.Incident_Number__c || '';
    const riskLevel = payload.Risk_Level__c || '';
    const message = payload.Message__c || '';
    
    let toastTitle;
    let toastVariant = 'info';
    let triggerToast = false;
    
    if (eventType === 'INCIDENT_CREATED' && riskLevel === 'CRITICAL') {
        toastTitle = `🚨 CRITICAL Incident Detected (${incidentNumber})`;
        toastVariant = 'error';
        triggerToast = true;
    } else if (eventType === 'APPROVAL_REQUIRED') {
        toastTitle = `🔒 Guardian Gate: Action Approval Required (${incidentNumber})`;
        toastVariant = 'warning';
        triggerToast = true;
    } else if (eventType === 'ACTION_EXECUTED') {
        toastTitle = `✅ Zentom Auto-Heal: Action Executed (${incidentNumber})`;
        toastVariant = 'success';
        triggerToast = true;
    }
    
    if (triggerToast) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: toastTitle,
                message: message,
                variant: toastVariant,
                mode: 'dismissible'
            })
        );
    }
}
```

---

## 5. Multiple Channel Subscription Mapping

The Command Center must listen to:
1. `SentinelFlow_Dashboard_Event__e` (Dashboard Telemetry)
2. `Integration_Health_Event__e` (Integration Health Metrics)

This ensures both the incident queues and the integration health signals update live in the UI.

```javascript
_subscribeToStreamingChannels() {
    const DASHBOARD_CHANNEL = '/event/SentinelFlow_Dashboard_Event__e';
    const INTEGRATION_CHANNEL = '/event/Integration_Health_Event__e';
    
    // Register global error listener
    registerErrorHandler((error) => {
        console.warn('[ZentomDashboard] Streaming connection issue:', error);
        this.isStreamingActive = false;
        // Signal adaptive polling to revert to 30s interval
        this.handleStreamingDisconnect();
    });
    
    // 1. Subscribe to SentinelFlow Dashboard Event
    subscribeToChannel(DASHBOARD_CHANNEL, -1, (response) => {
        this.isStreamingActive = true;
        this.handleIncomingTelemetryEvent(response);
    })
    .then((sub) => {
        this._dashboardSubscription = sub;
    })
    .catch((err) => {
        console.error('[ZentomDashboard] Dashboard channel subscription failed:', err);
    });
    
    // 2. Subscribe to Integration Health Event
    subscribeToChannel(INTEGRATION_CHANNEL, -1, (response) => {
        this.isStreamingActive = true;
        this.debouncedRefresh();
    })
    .then((sub) => {
        this._integrationSubscription = sub;
    })
    .catch((err) => {
        console.error('[ZentomDashboard] Integration channel subscription failed:', err);
    });
}
```

---

## 6. Cleanup & Lifecycle Management

It is critical to unsubscribe from all active channels when the component is unmounted or removed from the DOM. Failing to do so causes CometD memory leaks and background LWC performance degradation in the browser.

```javascript
connectedCallback() {
    // 1. Establish real-time streaming subscriptions
    this._subscribeToStreamingChannels();
    
    // 2. Start adaptive fallback polling timer (detailed in 48D)
    this._startAdaptivePolling();
}

disconnectedCallback() {
    console.log('[ZentomDashboard] Component disconnected. Cleaning up streaming subscriptions...');
    
    // Unsubscribe from Dashboard channel
    if (this._dashboardSubscription) {
        unsubscribeFromChannel(this._dashboardSubscription)
            .then(() => { this._dashboardSubscription = null; })
            .catch(err => console.error('[ZentomDashboard] Error unsubscribing dashboard:', err));
    }
    
    // Unsubscribe from Integration channel
    if (this._integrationSubscription) {
        unsubscribeFromChannel(this._integrationSubscription)
            .then(() => { this._integrationSubscription = null; })
            .catch(err => console.error('[ZentomDashboard] Error unsubscribing integration:', err));
    }
    
    // Clear adaptive fallback polling timer
    this._stopAdaptivePolling();
}
```

---

## 7. Streaming Security and Error Safety

1. **Graceful Subscribing**: If the running user lacks `Read` access to `SentinelFlow_Dashboard_Event__e`, the subscription `catch` block intercepts the failure, logs a console warning, and ensures the user degrades gracefully to polling.
2. **Error Boundary**: If CometD drops out or reconnects (firing `onError`), the global error handler is called, setting `isStreamingActive = false` so the fallback polling mechanism instantly speeds up from 60s to 30s. No ugly UI error popups are shown; fallback polling is fully transparent.
3. **Idempotence**: `refreshApex()` is idempotent. If a Platform Event triggers a refresh at the exact same moment a fallback poll is running, Salesforce LDS will optimize the network requests, ensuring no duplicate queries are executed.

---

## 8. Implementation Checklist for Milestone 48C

- [ ] Create the directory `force-app/main/default/lwc/streamingTelemetry`
- [ ] Create `streamingTelemetry.js-meta.xml` (isExposed = false)
- [ ] Create `streamingTelemetry.js` implementation file
- [ ] Modify `zentomDashboard.js` to import the new utility module
- [ ] Integrate debounced event listener and multiple channel registration in `zentomDashboard`
- [ ] Add active subscription handles and lifecycle cleanup in `zentomDashboard`
