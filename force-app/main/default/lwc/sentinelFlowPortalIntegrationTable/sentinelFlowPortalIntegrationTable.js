import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getActiveIntegrations from '@salesforce/apex/SentinelFlowPortalController.getActiveIntegrations';

export default class SentinelFlowPortalIntegrationTable extends NavigationMixin(LightningElement) {
    @api detailPagePath = 'integration-detail';
    rows = [];
    error;
    sortedBy      = 'status';
    sortDirection = 'desc';

    _subscription;
    _autoRefreshInterval;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._fetchData();
        // Auto-refresh every 10 s
        this._autoRefreshInterval = setInterval(() => { this._fetchData(); }, 10000);
        // Also refresh on Integration Health Platform Events
        subscribe('/event/Integration_Health_Event__e', -1, () => {
            this._fetchData();
        }).then(sub => { this._subscription = sub; })
          .catch(err => { console.warn('empApi subscribe failed:', err); });
    }

    disconnectedCallback() {
        clearInterval(this._autoRefreshInterval);
        if (this._subscription) unsubscribe(this._subscription, () => {});
    }

    // ── Data ──────────────────────────────────────────────────────────────────
    _fetchData() {
        getActiveIntegrations()
            .then(data => {
                this.rows  = this.sortData(data, this.sortedBy, this.sortDirection);
                this.error = undefined;
            })
            .catch(err => {
                this.rows  = [];
                this.error = 'Unable to load live integration data.';
                console.error('Integration fetch error', err);
            });
    }

    @api
    refreshData() {
        this._fetchData();
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get hasRows()  { return this.rows.length > 0; }
    get rowCount() { return this.rows.length; }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleHeaderSort(event) {
        const fieldName = event.currentTarget.dataset.field;
        this.sortDirection =
            this.sortedBy === fieldName && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortedBy = fieldName;
        this.rows = this.sortData(this.rows, this.sortedBy, this.sortDirection);
    }

    handleViewDetail(event) {
        const row = this.rows.find(item => item.id === event.currentTarget.dataset.id);
        if (!row) return;
        const basePath = this.getCommunityBasePath();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${basePath}${this.detailPagePath}?c__recordId=${row.id}` }
        });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    sortData(data, fieldName, sortDirection) {
        const direction = sortDirection === 'asc' ? 1 : -1;
        return [...data]
            .sort((left, right) => {
                const leftValue  = left[fieldName]  ?? '';
                const rightValue = right[fieldName] ?? '';
                return leftValue > rightValue ? direction : leftValue < rightValue ? -direction : 0;
            })
            .map(row => ({
                ...row,
                statusClass:        this.getStatusClass(row.status),
                responseTimeLabel:  this.formatResponseTime(row.responseTime)
            }));
    }

    getCommunityBasePath() {
        const marker = '/s/';
        const currentPath = window.location.pathname;
        const markerIndex = currentPath.indexOf(marker);
        return markerIndex >= 0 ? currentPath.substring(0, markerIndex + marker.length) : '/';
    }

    getStatusClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'failed')  return 'pill status-failed';
        if (s === 'warning') return 'pill status-warning';
        if (s === 'success') return 'pill status-success';
        return 'pill status-default';
    }

    formatResponseTime(value) {
        return value ? `${value} ms` : 'N/A';
    }
}