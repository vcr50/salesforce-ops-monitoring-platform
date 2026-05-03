import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getSummary from '@salesforce/apex/SentinelFlowPortalController.getSummary';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class SentinelFlowPortalSummary extends LightningElement {
    // KPI values
    criticalIncidents  = 0;
    openIncidents      = 0;
    failedIntegrations = 0;
    warningIntegrations = 0;
    totalRevenueAtRisk  = 0;
    totalUsersAffected  = 0;
    autoHealedToday     = 0;

    error;
    lastRefreshedLabel = 'Loading…';
    isRefreshing       = false;

    // empApi subscription for real-time updates
    _subscription;
    _wiredResult;

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(getSummary)
    wiredSummary(result) {
        this._wiredResult = result;
        const { error, data } = result;
        if (data) {
            this._applyData(data);
        } else if (error) {
            this.error = 'Unable to load live summary data.';
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._subscribeToEvents();
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription, () => {});
        }
    }

    // ── Platform Event subscription ───────────────────────────────────────────
    _subscribeToEvents() {
        const channel = '/event/Integration_Health_Event__e';
        subscribe(channel, -1, () => {
            // Re-fetch summary whenever an integration health event fires
            this._refresh();
        }).then(sub => {
            this._subscription = sub;
        }).catch(err => {
            console.warn('SentinelFlow empApi subscribe failed:', err);
        });

        onError(err => {
            console.error('SentinelFlow empApi error:', err);
        });
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleRefresh() {
        this._refresh();
    }

    @api
    refreshData() {
        this._refresh();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _applyData(data) {
        this.criticalIncidents   = data.criticalIncidents   ?? 0;
        this.openIncidents       = data.openIncidents       ?? 0;
        this.failedIntegrations  = data.failedIntegrations  ?? 0;
        this.warningIntegrations = data.warningIntegrations ?? 0;
        this.totalRevenueAtRisk  = data.totalRevenueAtRisk  ?? 0;
        this.totalUsersAffected  = data.totalUsersAffected  ?? 0;
        this.autoHealedToday     = data.autoHealedToday     ?? 0;
        this.error               = undefined;
        this.lastRefreshedLabel  = new Date().toLocaleString();
    }

    _refresh() {
        this.isRefreshing = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isRefreshing = false;
        });
    }

    // ── Computed getters ──────────────────────────────────────────────────────
    get revenueFormatted() {
        const n = this.totalRevenueAtRisk;
        if (n >= 1000000) return '$' + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000)    return '$' + (n / 1000).toFixed(0) + 'K';
        return '$' + n.toFixed(0);
    }

    get usersFormatted() {
        return this.totalUsersAffected.toLocaleString();
    }

    get hasError() {
        return !!this.error;
    }

    get systemStatusLabel() {
        if (this.criticalIncidents > 0) return 'Critical';
        if (this.failedIntegrations > 0) return 'Degraded';
        return 'Healthy';
    }

    get systemStatusClass() {
        if (this.criticalIncidents > 0) return 'status-indicator status-critical';
        if (this.failedIntegrations > 0) return 'status-indicator status-warning';
        return 'status-indicator status-healthy';
    }
}
