import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import getDashboardData from '@salesforce/apex/ZentomDashboardController.getDashboardData';

const POLL_INTERVAL_MS = 30000; // 30 seconds near-realtime polling

export default class ZentomDashboard extends NavigationMixin(LightningElement) {
    dateRange = 'LAST_7_DAYS';
    data;
    errorMessage;
    lastRefreshed;
    wiredDashboard;
    _pollTimer;

    // ── Milestone 43: Filter state ──────────────────────────────────────
    @track filterRisk = 'ALL';
    @track filterStatus = 'ALL';
    @track isFilterOpen = false;

    // ── Risk filter options ─────────────────────────────────────────────
    get riskOptions() {
        return [
            { label: 'All Risk Levels', value: 'ALL' },
            { label: 'Critical', value: 'CRITICAL' },
            { label: 'High', value: 'HIGH' },
            { label: 'Medium', value: 'MEDIUM' },
            { label: 'Low', value: 'LOW' }
        ];
    }

    // ── Status filter options ───────────────────────────────────────────
    get statusOptions() {
        return [
            { label: 'All Statuses', value: 'ALL' },
            { label: 'Open', value: 'Open' },
            { label: 'Approval Required', value: 'Approval Required' },
            { label: 'Executed', value: 'Executed' },
            { label: 'Closed', value: 'Closed' }
        ];
    }

    // ── Active filter count badge ───────────────────────────────────────
    get activeFilterCount() {
        let count = 0;
        if (this.filterRisk !== 'ALL') count++;
        if (this.filterStatus !== 'ALL') count++;
        return count;
    }

    get hasActiveFilters() {
        return this.activeFilterCount > 0;
    }

    get filterToggleClass() {
        return this.hasActiveFilters
            ? 'filter-toggle filter-toggle-active'
            : 'filter-toggle';
    }

    // ── Wire + polling ──────────────────────────────────────────────────
    @wire(getDashboardData, { dateRange: '$dateRange' })
    wiredGetDashboardData(result) {
        this.wiredDashboard = result;
        if (result.data) {
            this.data = result.data;
            this.errorMessage = undefined;
            this.lastRefreshed = new Date();
        } else if (result.error) {
            this.data = undefined;
            this.errorMessage = this.reduceError(result.error);
        }
    }

    connectedCallback() {
        this._pollTimer = setInterval(() => {
            if (this.wiredDashboard) {
                refreshApex(this.wiredDashboard);
            }
        }, POLL_INTERVAL_MS);
    }

    disconnectedCallback() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
        }
    }

    // ── Summary metric getters (Milestone 43 telemetry widgets) ─────────
    get summaryTotalIncidents() {
        return this.data?.summary?.totalIncidents ?? 0;
    }

    get summaryCriticalIncidents() {
        return this.data?.summary?.criticalIncidents ?? 0;
    }

    get summaryPendingApprovals() {
        return this.data?.summary?.pendingApprovals ?? 0;
    }

    get summaryExecutedActions() {
        return this.data?.summary?.executedActions ?? 0;
    }

    get summaryReplayEvents() {
        return this.data?.summary?.recentReplayEvents ?? 0;
    }

    // ── Trend indicators ────────────────────────────────────────────────
    get criticalTrendClass() {
        return this.summaryCriticalIncidents > 0
            ? 'trend-indicator trend-up'
            : 'trend-indicator trend-stable';
    }

    get criticalTrendLabel() {
        return this.summaryCriticalIncidents > 0 ? '↑ Active' : '● Stable';
    }

    get approvalTrendClass() {
        return this.summaryPendingApprovals > 0
            ? 'trend-indicator trend-warn'
            : 'trend-indicator trend-stable';
    }

    get approvalTrendLabel() {
        return this.summaryPendingApprovals > 0 ? '⚠ Pending' : '✓ Clear';
    }

    // ── Freshness pill ──────────────────────────────────────────────────
    get freshnessLabel() {
        if (!this.lastRefreshed) return 'Loading…';
        const secs = Math.floor((Date.now() - this.lastRefreshed.getTime()) / 1000);
        if (secs < 60) return `${secs}s ago`;
        return `${Math.floor(secs / 60)}m ago`;
    }

    // ── Filtered data getters ───────────────────────────────────────────
    get filteredIncidents() {
        const rows = this.decorateRows(this.data?.recentIncidents || []);
        return this._applyFilters(rows);
    }

    _applyFilters(rows) {
        return rows.filter((row) => {
            const riskMatch =
                this.filterRisk === 'ALL' || row.riskLevel === this.filterRisk;
            const statusMatch =
                this.filterStatus === 'ALL' || row.status === this.filterStatus;
            return riskMatch && statusMatch;
        });
    }

    get hasFilteredIncidents() {
        return this.filteredIncidents.length > 0;
    }

    // ── Original getters ────────────────────────────────────────────────
    get topRunbook() {
        return this.data?.summary?.topRunbook || 'None';
    }

    get lastRefreshedLabel() {
        return this.lastRefreshed ? this.lastRefreshed.toLocaleString() : 'Not loaded';
    }

    get activeRangeLabel() {
        if (this.dateRange === 'TODAY') return 'Today';
        if (this.dateRange === 'ALL') return 'All time';
        return 'Last 7 days';
    }

    get failedExecutionLabel() {
        const failedRows = (this.data?.recentIncidents || []).filter(
            (row) => row.executionStatus === 'Failed'
        );
        return String(failedRows.length);
    }

    get systemHealthLabel() {
        if (this.errorMessage) return 'Attention';
        if (this.data?.summary?.criticalIncidents > 0 || this.data?.summary?.pendingApprovals > 0) {
            return 'Watch';
        }
        return 'Operational';
    }

    get hostedDbStatusLabel() {
        return this.data ? 'Not reported' : 'Unavailable';
    }

    get latestErrorLogLabel() {
        return this.failedExecutionLabel === '0'
            ? 'None surfaced'
            : `${this.failedExecutionLabel} action issue(s)`;
    }

    get systemHealthClass() {
        if (this.errorMessage) return 'badge critical-badge';
        if (this.data?.summary?.criticalIncidents > 0 || this.data?.summary?.pendingApprovals > 0) {
            return 'badge warning-badge';
        }
        return 'badge success-badge';
    }

    get orgHealthClass() {
        const status = this.data?.summary?.orgHealthStatus;
        if (status === 'Healthy') return 'health-card health-healthy';
        if (status === 'Stable') return 'health-card health-stable';
        if (status === 'At Risk') return 'health-card health-warning';
        if (status === 'Critical') return 'health-card health-critical';
        return 'health-card health-stable';
    }

    get showLoading() {
        return !this.data && !this.errorMessage;
    }

    get recentIncidents() {
        return this.decorateRows(this.data?.recentIncidents || []);
    }

    get pendingApprovals() {
        return this.decorateRows(this.data?.pendingApprovals || []);
    }

    get recentExecutions() {
        return this.decorateRows(this.data?.recentExecutions || []);
    }

    get recentReplayEvents() {
        return (this.data?.recentReplayEvents || []).map((row) => ({
            ...row,
            createdLabel: this.formatDateTime(row.createdDate),
            decisionClass: `badge ${this.decisionClass(row.decision)}`
        }));
    }

    get recentCasesCreated() {
        return this.decorateRows(this.data?.recentCasesCreated || []);
    }

    get hasRecentIncidents() {
        return this.recentIncidents.length > 0;
    }

    get hasPendingApprovals() {
        return this.pendingApprovals.length > 0;
    }

    get hasRecentExecutions() {
        return this.recentExecutions.length > 0;
    }

    get hasRecentReplayEvents() {
        return this.recentReplayEvents.length > 0;
    }

    get hasRecentCasesCreated() {
        return this.recentCasesCreated.length > 0;
    }

    // ── Event handlers ──────────────────────────────────────────────────
    handleRangeChange(event) {
        this.dateRange = event.target.dataset.range;
        refreshApex(this.wiredDashboard);
    }

    handleRefresh() {
        refreshApex(this.wiredDashboard);
    }

    handleToggleFilters() {
        this.isFilterOpen = !this.isFilterOpen;
    }

    handleFilterRiskChange(event) {
        this.filterRisk = event.detail.value;
    }

    handleFilterStatusChange(event) {
        this.filterStatus = event.detail.value;
    }

    handleClearFilters() {
        this.filterRisk = 'ALL';
        this.filterStatus = 'ALL';
    }

    openIncident(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Sentinel_Incident__c',
                actionName: 'view'
            }
        });
    }

    openCase(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    // ── Helpers ─────────────────────────────────────────────────────────
    decorateRows(rows) {
        return rows.map((row) => ({
            ...row,
            riskLabel: row.riskScore
                ? `${row.riskScore} / ${row.riskLevel || 'Unknown'}`
                : row.riskLevel,
            riskClass: `badge ${this.riskClass(row.riskLevel)}`,
            statusClass: `badge ${this.statusClass(row.status, row.executionStatus)}`,
            executionClass: `badge ${this.statusClass(row.status, row.executionStatus)}`,
            createdLabel: this.formatDate(row.createdDate),
            executedLabel: this.formatDateTime(row.executedAt),
            caseLabel: row.createdCaseNumber ? `Case ${row.createdCaseNumber}` : 'No case',
            environmentLabel: 'Salesforce',
            recommendedActionLabel:
                row.executionAction || row.runbookKey || 'Review recommendation'
        }));
    }

    riskClass(riskLevel) {
        if (riskLevel === 'CRITICAL') return 'critical-badge';
        if (riskLevel === 'HIGH') return 'high-badge';
        if (riskLevel === 'MEDIUM') return 'medium-badge';
        return 'low-badge';
    }

    statusClass(status, executionStatus) {
        if (executionStatus === 'Executed') return 'success-badge';
        if (status === 'Approval Required') return 'warning-badge';
        return 'neutral-badge';
    }

    decisionClass(decision) {
        if (decision === 'Rejected') return 'critical-badge';
        if (decision === 'Approved' || decision === 'Executed') return 'success-badge';
        if (decision === 'Pending Approval') return 'warning-badge';
        return 'neutral-badge';
    }

    formatDate(value) {
        return value ? new Date(value).toLocaleDateString() : '';
    }

    formatDateTime(value) {
        return value ? new Date(value).toLocaleString() : '';
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unable to load dashboard.';
    }
}
