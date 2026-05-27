import { LightningElement, api, track } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getSummary from '@salesforce/apex/SentinelFlowPortalController.getSummary';
import getCurrencyConfig from '@salesforce/apex/SettingsController.getCurrencyConfig';

export default class SentinelFlowPortalSummary extends LightningElement {
    // KPI values
    criticalIncidents   = 0;
    openIncidents       = 0;
    failedIntegrations  = 0;
    warningIntegrations = 0;
    totalRevenueAtRisk  = 0;
    totalUsersAffected  = 0;
    autoHealedToday     = 0;

    error;
    lastRefreshedLabel = 'Loading…';
    isRefreshing       = false;

    _subscription;

    @track currencySymbol = '$';
    @track currencyRate = 1.0;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._fetchData();
        this._subscribeToEvents();
        this._loadCurrency();
    }

    _loadCurrency() {
        getCurrencyConfig()
            .then(config => {
                if (config) {
                    this.currencySymbol = config.symbol || '$';
                    this.currencyRate = config.rate || 1.0;
                }
            })
            .catch(err => {
                console.error('Error loading currency config:', err);
            });
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription, () => {});
        }
    }

    // ── Platform Event subscription ───────────────────────────────────────────
    _subscribeToEvents() {
        subscribe('/event/Integration_Health_Event__e', -1, () => {
            this._fetchData();
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
    _fetchData() {
        getSummary()
            .then(data  => { this._applyData(data); })
            .catch(err  => {
                this.error = 'Unable to load live summary data.';
                console.error('Summary fetch error', err);
            });
    }

    _refresh() {
        this.isRefreshing = true;
        getSummary()
            .then(data  => { this._applyData(data); })
            .catch(err  => {
                this.error = 'Unable to load live summary data.';
                console.error('Summary fetch error', err);
            })
            .finally(() => { this.isRefreshing = false; });
    }

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

    // ── Computed getters ──────────────────────────────────────────────────────
    get revenueFormatted() {
        const n = this.totalRevenueAtRisk * this.currencyRate;
        const sym = this.currencySymbol;
        if (n >= 1000000) return sym + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000)    return sym + (n / 1000).toFixed(0) + 'K';
        return sym + n.toFixed(0);
    }

    get usersFormatted() {
        return this.totalUsersAffected.toLocaleString();
    }

    get hasError() {
        return !!this.error;
    }

    get systemStatusLabel() {
        if (this.criticalIncidents > 0)  return 'Critical';
        if (this.failedIntegrations > 0) return 'Degraded';
        return 'Healthy';
    }

    get systemStatusClass() {
        if (this.criticalIncidents > 0)  return 'status-indicator status-critical';
        if (this.failedIntegrations > 0) return 'status-indicator status-warning';
        return 'status-indicator status-healthy';
    }
}