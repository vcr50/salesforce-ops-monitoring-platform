/**
 * streamingTelemetry.js
 * LWC service module that manages empApi subscriptions for SentinelFlow_Dashboard_Event__e.
 * Provides subscribe, unsubscribe, and reconnect APIs consumed by zentomDashboard.
 *
 * Design constraints (49D):
 *  - Does NOT replace polling — used as an enhancement on top of existing 30s poll.
 *  - Debounces rapid-fire events into a single refresh call (2-second window).
 *  - Reconnects silently on CometD transport error up to MAX_RECONNECT_ATTEMPTS times.
 *  - Subscribes from replay position -1 (latest events only, no replay on reconnect).
 *  - Cleans up all timers and subscriptions when the caller invokes unsubscribe().
 *
 * @author TomCodeX Engineering
 */

import { subscribe, unsubscribe, onError, isEmpEnabled } from 'lightning/empApi';

// Platform Event channel for SentinelFlow dashboard telemetry
const CHANNEL = '/event/SentinelFlow_Dashboard_Event__e';

// Debounce window — coalesce rapid burst events into one refresh
const DEBOUNCE_MS = 2000;

// Maximum silent reconnect attempts before giving up
const MAX_RECONNECT_ATTEMPTS = 5;

// Backoff multiplier for reconnect delays (1s, 2s, 4s, 8s, 16s)
const RECONNECT_BASE_MS = 1000;

/**
 * Creates and manages a streaming telemetry session.
 *
 * @param {Function} onRefresh   - Called (debounced) when dashboard data should be refreshed.
 * @param {Function} onEventType - Optional: called immediately with the event type string
 *                                  so the caller can show a toast or update a status indicator.
 * @param {Function} onError     - Optional: called with an error message string on unrecoverable failure.
 * @returns {Object} session handle with { subscribe, unsubscribe } methods.
 */
export function createStreamingSession({ onRefresh, onEventReceived, onStreamError }) {
    let _subscription = null;
    let _debounceTimer = null;
    let _reconnectCount = 0;
    let _reconnectTimer = null;
    let _destroyed = false;

    // ── Internal helpers ─────────────────────────────────────────────────

    function _scheduleRefresh() {
        if (_destroyed) return;
        if (_debounceTimer) {
            clearTimeout(_debounceTimer);
        }
        _debounceTimer = setTimeout(() => {
            _debounceTimer = null;
            if (!_destroyed && typeof onRefresh === 'function') {
                onRefresh();
            }
        }, DEBOUNCE_MS);
    }

    function _handleEvent(message) {
        if (_destroyed) return;
        const payload = message?.data?.payload;
        const eventType = payload?.Event_Type__c || 'UNKNOWN';

        // Notify caller immediately with event type for UI indicators
        if (typeof onEventReceived === 'function') {
            onEventReceived({ eventType, payload });
        }

        // Schedule a debounced data refresh
        _scheduleRefresh();
    }

    function _handleError(error) {
        if (_destroyed) return;
        const msg = typeof error === 'string' ? error : JSON.stringify(error);
        console.warn('[streamingTelemetry] CometD transport error:', msg);
        _attemptReconnect();
    }

    function _attemptReconnect() {
        if (_destroyed) return;
        if (_reconnectCount >= MAX_RECONNECT_ATTEMPTS) {
            const errMsg = `Streaming telemetry disconnected after ${MAX_RECONNECT_ATTEMPTS} reconnect attempts. Polling fallback active.`;
            console.error('[streamingTelemetry]', errMsg);
            if (typeof onStreamError === 'function') {
                onStreamError(errMsg);
            }
            return;
        }

        const delay = RECONNECT_BASE_MS * Math.pow(2, _reconnectCount);
        _reconnectCount++;
        console.info(`[streamingTelemetry] Reconnect attempt ${_reconnectCount} in ${delay}ms…`);

        _reconnectTimer = setTimeout(async () => {
            if (_destroyed) return;
            try {
                await _doSubscribe();
                _reconnectCount = 0; // reset on success
                console.info('[streamingTelemetry] Reconnected successfully.');
            } catch (err) {
                console.warn('[streamingTelemetry] Reconnect failed:', err);
                _attemptReconnect();
            }
        }, delay);
    }

    async function _doSubscribe() {
        if (_subscription) {
            try { await unsubscribe(_subscription, () => {}); } catch (_) { /* ignore */ }
            _subscription = null;
        }
        // Subscribe from replay -1 (only new events, no historic replay on reconnect)
        _subscription = await subscribe(CHANNEL, -1, _handleEvent);
    }

    // ── Public API ───────────────────────────────────────────────────────

    async function start() {
        if (_destroyed) return;
        try {
            const enabled = await isEmpEnabled();
            if (!enabled) {
                console.warn('[streamingTelemetry] empApi is not available in this context. Polling fallback active.');
                if (typeof onStreamError === 'function') {
                    onStreamError('empApi not available — streaming telemetry disabled. Polling fallback active.');
                }
                return;
            }
            // Register global CometD error listener
            onError(_handleError);
            await _doSubscribe();
            console.info('[streamingTelemetry] Subscribed to', CHANNEL);
        } catch (err) {
            const msg = `Failed to subscribe to streaming channel: ${err?.message || JSON.stringify(err)}`;
            console.error('[streamingTelemetry]', msg);
            if (typeof onStreamError === 'function') {
                onStreamError(msg);
            }
        }
    }

    function stop() {
        _destroyed = true;
        if (_debounceTimer) {
            clearTimeout(_debounceTimer);
            _debounceTimer = null;
        }
        if (_reconnectTimer) {
            clearTimeout(_reconnectTimer);
            _reconnectTimer = null;
        }
        if (_subscription) {
            unsubscribe(_subscription, () => {
                console.info('[streamingTelemetry] Unsubscribed from', CHANNEL);
            });
            _subscription = null;
        }
    }

    return { start, stop };
}
