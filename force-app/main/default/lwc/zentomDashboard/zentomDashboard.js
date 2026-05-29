import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { createStreamingSession } from 'c/streamingTelemetry';

import getDashboardData from '@salesforce/apex/ZentomDashboardController.getDashboardData';
import getReplayExportData from '@salesforce/apex/ZentomDashboardController.getReplayExportData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const POLL_INTERVAL_MS = 60000; // 60s baseline — streaming covers near-real-time; poll is the safety net

export default class ZentomDashboard extends NavigationMixin(LightningElement) {
    dateRange = 'LAST_7_DAYS';
    data;
    errorMessage;
    lastRefreshed;
    wiredDashboard;
    _pollTimer;

    // ── Milestone 49D: Streaming telemetry state ─────────────────────────
    _streamingSession = null;
    @track _streamingActive = false;
    @track _lastEventType = null;

    // ── Milestone 43: Filter state ──────────────────────────────────────
    @track filterRisk = 'ALL';
    @track filterStatus = 'ALL';
    @track filterEnvironment = 'ALL';
    @track filterType = 'ALL';
    @track filterAiStatus = 'ALL';
    @track presetView = 'ALL';
    @track isFilterOpen = false;

    // ── Preset view options ─────────────────────────────────────────────
    get presetOptions() {
        return [
            { label: 'None', value: 'ALL' },
            { label: 'Needs Approval', value: 'NEEDS_APPROVAL' },
            { label: 'Critical Production', value: 'CRITICAL_PROD' },
            { label: 'Recent Failures', value: 'RECENT_FAILURES' },
            { label: 'AI High Confidence', value: 'AI_HIGH_CONF' },
            { label: 'AI Review Needed', value: 'AI_REVIEW' },
            { label: 'Executed Today', value: 'EXECUTED_TODAY' }
        ];
    }

    // ── Time range options ──────────────────────────────────────────────
    get timeRangeOptions() {
        return [
            { label: 'Today', value: 'TODAY' },
            { label: 'Last 7 Days', value: 'LAST_7_DAYS' },
            { label: 'All Time', value: 'ALL' }
        ];
    }

    // ── Environment filter options ──────────────────────────────────────
    get environmentOptions() {
        return [
            { label: 'All Environments', value: 'ALL' },
            { label: 'Production', value: 'production' },
            { label: 'Sandbox', value: 'sandbox' }
        ];
    }

    // ── Incident Type filter options ────────────────────────────────────
    get typeOptions() {
        return [
            { label: 'All Types', value: 'ALL' },
            { label: 'Flow Failure', value: 'FLOW_FAILURE' },
            { label: 'Integration Error', value: 'INTEGRATION_ERROR' },
            { label: 'Apex Exception', value: 'APEX_EXCEPTION' },
            { label: 'Security Event', value: 'SECURITY_EVENT' }
        ];
    }

    // ── AI Status filter options ────────────────────────────────────────
    get aiStatusOptions() {
        return [
            { label: 'All AI Statuses', value: 'ALL' },
            { label: 'High Confidence (>80)', value: 'HIGH_CONFIDENCE' },
            { label: 'Review Needed (≤80)', value: 'REVIEW_NEEDED' },
            { label: 'Active Reasoning', value: 'ACTIVE' }
        ];
    }

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
        if (this.filterEnvironment !== 'ALL') count++;
        if (this.filterType !== 'ALL') count++;
        if (this.filterAiStatus !== 'ALL') count++;
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
        // ── Polling fallback (safety net) ────────────────────────────────
        this._pollTimer = setInterval(() => {
            if (this.wiredDashboard) {
                refreshApex(this.wiredDashboard);
            }
        }, POLL_INTERVAL_MS);

        // ── Streaming telemetry (49D) ────────────────────────────────────
        this._streamingSession = createStreamingSession({
            onRefresh:       () => this._handleStreamRefresh(),
            onEventReceived: (detail) => this._handleStreamEvent(detail),
            onStreamError:   (msg) => this._handleStreamError(msg)
        });
        this._streamingSession.start();
    }

    disconnectedCallback() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
            this._pollTimer = null;
        }
        // Cleanly unsubscribe and cancel all streaming timers
        if (this._streamingSession) {
            this._streamingSession.stop();
            this._streamingSession = null;
        }
    }

    // ── Streaming telemetry handlers (49D) ──────────────────────────────
    _handleStreamRefresh() {
        if (this.wiredDashboard) {
            refreshApex(this.wiredDashboard);
        }
    }

    _handleStreamEvent({ eventType }) {
        this._streamingActive = true;
        this._lastEventType = eventType;
    }

    _handleStreamError(msg) {
        // Streaming is unavailable — degrade gracefully to polling-only
        this._streamingActive = false;
        console.warn('[zentomDashboard] Streaming degraded to polling:', msg);
        // Only surface a toast if it is a genuine connection failure (not 'not available')
        if (!msg.includes('not available')) {
            this.showToast('Live Updates', 'Streaming connection lost. Refreshing via polling.', 'warning');
        }
    }

    // ── Streaming status getters (49D) ───────────────────────────────────
    get streamingActive() {
        return this._streamingActive;
    }

    get lastEventTypeLabel() {
        return this._lastEventType ? `⚡ ${this._lastEventType.replace(/_/g, ' ')}` : '';
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
            const riskMatch = this.filterRisk === 'ALL' || row.riskLevel === this.filterRisk;
            const statusMatch = this.filterStatus === 'ALL' || row.status === this.filterStatus;
            const envMatch = this.filterEnvironment === 'ALL' || (row.environment && row.environment.toLowerCase() === this.filterEnvironment.toLowerCase());
            const typeMatch = this.filterType === 'ALL' || row.incidentType === this.filterType;
            
            let aiMatch = true;
            if (this.filterAiStatus === 'HIGH_CONFIDENCE') {
                aiMatch = row.aiConfidence > 80;
            } else if (this.filterAiStatus === 'REVIEW_NEEDED') {
                aiMatch = row.aiConfidence <= 80;
            } else if (this.filterAiStatus === 'ACTIVE') {
                aiMatch = row.aiStatus === 'ACTIVE';
            }

            return riskMatch && statusMatch && envMatch && typeMatch && aiMatch;
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
        this.dateRange = event.detail ? event.detail.value : event.target.dataset.range;
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
        this.presetView = 'ALL';
    }

    handleFilterStatusChange(event) {
        this.filterStatus = event.detail.value;
        this.presetView = 'ALL';
    }

    handleFilterEnvironmentChange(event) {
        this.filterEnvironment = event.detail.value;
        this.presetView = 'ALL';
    }

    handleFilterTypeChange(event) {
        this.filterType = event.detail.value;
        this.presetView = 'ALL';
    }

    handleFilterAiStatusChange(event) {
        this.filterAiStatus = event.detail.value;
        this.presetView = 'ALL';
    }

    handlePresetChange(event) {
        this.presetView = event.detail.value;
        if (this.presetView === 'NEEDS_APPROVAL') {
            this.handleClearFilters();
            this.filterStatus = 'Approval Required';
        } else if (this.presetView === 'CRITICAL_PROD') {
            this.handleClearFilters();
            this.filterRisk = 'CRITICAL';
            this.filterEnvironment = 'production';
        } else if (this.presetView === 'RECENT_FAILURES') {
            this.handleClearFilters();
            this.filterType = 'FLOW_FAILURE';
        } else if (this.presetView === 'AI_HIGH_CONF') {
            this.handleClearFilters();
            this.filterAiStatus = 'HIGH_CONFIDENCE';
        } else if (this.presetView === 'AI_REVIEW') {
            this.handleClearFilters();
            this.filterAiStatus = 'REVIEW_NEEDED';
        } else if (this.presetView === 'EXECUTED_TODAY') {
            this.handleClearFilters();
            this.filterStatus = 'Closed';
            this.dateRange = 'TODAY';
            refreshApex(this.wiredDashboard);
        }
    }

    handleClearFilters() {
        this.filterRisk = 'ALL';
        this.filterStatus = 'ALL';
        this.filterEnvironment = 'ALL';
        this.filterType = 'ALL';
        this.filterAiStatus = 'ALL';
        this.presetView = 'ALL';
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

    // ── Milestone 43E: Replay Export & Share ─────────────────────────────
    async handleExportCsv(event) {
        const incidentId = event.currentTarget.dataset.id;
        try {
            const data = await getReplayExportData({ incidentId });
            let csv = 'Event Name,Event Time,Event Details,Actor\n';
            if (data.events) {
                data.events.forEach(ev => {
                    const safeDetails = ev.eventDetails ? ev.eventDetails.replace(/"/g, '""') : '';
                    csv += `"${ev.eventName}","${ev.eventTime}","${safeDetails}","${ev.actor}"\n`;
                });
            }
            const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `Sentinel_Incident_${data.incidentName}_Timeline.csv`);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            this.showToast('Success', 'CSV exported successfully.', 'success');
        } catch (error) {
            this.showToast('Export Error', this.reduceError(error), 'error');
        }
    }

    async handleCopySummary(event) {
        const incidentId = event.currentTarget.dataset.id;
        try {
            const data = await getReplayExportData({ incidentId });
            const summary = `Incident: ${data.incidentName}
Risk: ${data.riskLevel}
Policy: ${data.policyDecision}
Approval: ${data.approvalStatus}
Execution: ${data.executionStatus}
Replay Events: ${data.events ? data.events.length : 0}
AI Explanation: ${data.events && data.events.length > 0 ? data.events[data.events.length - 1].eventDetails : 'N/A'}`;
            
            await navigator.clipboard.writeText(summary);
            this.showToast('Success', 'Summary copied to clipboard', 'success');
        } catch (error) {
            this.showToast('Copy Error', this.reduceError(error), 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
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
            environmentLabel: row.environment ? (row.environment.charAt(0).toUpperCase() + row.environment.slice(1).toLowerCase()) : 'Salesforce',
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
