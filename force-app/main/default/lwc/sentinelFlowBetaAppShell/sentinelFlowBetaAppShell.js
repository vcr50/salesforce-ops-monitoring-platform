import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/ZentomDashboardController.getDashboardData';
import getSystemHealth from '@salesforce/apex/SystemMonitorController.getSystemHealth';
import getUserContext from '@salesforce/apex/SystemMonitorController.getUserContext';
import approveWorkflow from '@salesforce/apex/ZentomDashboardController.approveWorkflow';
import rejectWorkflow from '@salesforce/apex/ZentomDashboardController.rejectWorkflow';
import sentinelFlowPulseLogo from '@salesforce/resourceUrl/sentinelFlowPulseLogo';

const PAGE_META = {
    command: {
        title: 'Operations Command Center',
        eyebrow: 'Unified Operations Dashboard',
        summary: 'Health, incidents, approvals, replay, and governed actions in one control surface.'
    },
    approvals: {
        title: 'Approval Queue',
        eyebrow: 'Human governance',
        summary: 'Review high-risk recommendations before execution.'
    },
    analytics: {
        title: 'Operational Analytics',
        eyebrow: 'Risk and trend visibility',
        summary: 'Track reliability posture, incident patterns, and business impact.'
    },
    copilot: {
        title: 'Zentom AI Console',
        eyebrow: 'AI operating layer',
        summary: 'Zentom is the intelligence layer. SentinelFlow is the product command center.'
    },
    incidents: {
        title: 'Incident Operations',
        eyebrow: 'Triage and evidence',
        summary: 'Inspect incidents, root cause, risk, and remediation state.'
    },
    settings: {
        title: 'System Settings',
        eyebrow: 'Admin controls',
        summary: 'Configure alerts, integrations, and runtime posture.'
    },
    actions: {
        title: 'Action Management',
        eyebrow: 'Automated operations',
        summary: 'View and manage all automated and manual actions executed by Zentom AI.'
    },
    runbooks: {
        title: 'Runbook Library',
        eyebrow: 'Operational playbooks',
        summary: 'Create, manage, and execute operational runbooks for incident response.'
    },
    policies: {
        title: 'Governance Policies',
        eyebrow: 'Risk and compliance',
        summary: 'Define governance policies, approval thresholds, and risk evaluation rules.'
    },
    cases: {
        title: 'Case Management',
        eyebrow: 'Incident-linked cases',
        summary: 'Track all Salesforce Cases created by SentinelFlow incidents and AI recommendations.'
    },
    reports: {
        title: 'Operational Reports',
        eyebrow: 'Analytics and insights',
        summary: 'Generate reports on incident trends, response times, and reliability metrics.'
    },
    integrations: {
        title: 'Integration Hub',
        eyebrow: 'Connected systems',
        summary: 'Connect external monitoring tools, CI/CD pipelines, and notification channels.'
    }
};

const FUTURE_MODULE_FLAGS = {
    showCases: false,
    showPolicies: false,
    showRunbooks: false
};

const DISABLED_FUTURE_PAGES = new Set(['cases', 'policies', 'runbooks']);

export default class SentinelFlowBetaAppShell extends NavigationMixin(LightningElement) {
    logoUrl = sentinelFlowPulseLogo;
    @track currentPage = 'command';
    @track currentTime = '';
    @track healthLabel = 'Checking';
    @track healthTone = 'checking';
    @track criticalCount = 0;
    @track isDarkMode = true;
    @track isSidebarOpen = false;
    @track isOrgMenuOpen = false;
    
    @track userName = 'Loading...';
    @track userProfile = 'Loading...';
    @track orgName = 'Loading...';
    @track searchKey = '';
    @track expandedEventName = '';

    // Filter & Sort State for Approvals
    @track approvalFilterRisk = 'ALL';
    @track approvalSortField = 'id';
    @track approvalSortAsc = true;
    @track approvalPage = 1;
    approvalPageSize = 5;

    // Filter & Sort State for Incidents
    @track incidentFilterRisk = 'ALL';
    @track incidentFilterStatus = 'ALL';
    @track incidentFilterEnv = 'ALL';
    @track incidentSortField = 'id';
    @track incidentSortAsc = false;
    @track incidentPage = 1;
    incidentPageSize = 5;

    // Quick Governance Review Modal State
    @track isReviewModalOpen = false;
    @track selectedReviewRow = null;
    @track approvalApproverName = '';
    @track rejectionReason = '';
    @track isApproving = true;
    @track isRefreshing = false;

    clock;
    _windowKeydownHandler;

    connectedCallback() {
        this.updateTime();
        this.clock = setInterval(() => this.updateTime(), 30000);
        try {
            const saved = localStorage.getItem('sf_theme');
            if (saved === 'light') this.isDarkMode = false;
            else if (saved === 'dark') this.isDarkMode = true;
        } catch(e) { /* noop */ }

        // Focus search box on '/' keypress
        this._windowKeydownHandler = (event) => {
            if (event.key === '/' && document.activeElement && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') {
                event.preventDefault();
                const searchInput = this.template.querySelector('.search-input');
                if (searchInput) {
                    searchInput.focus();
                }
            }
        };
        window.addEventListener('keydown', this._windowKeydownHandler);
    }

    _themeApplied = false;
    renderedCallback() {
        this._applyThemeClass();
    }

    disconnectedCallback() {
        if (this.clock) {
            clearInterval(this.clock);
        }
        if (this._windowKeydownHandler) {
            window.removeEventListener('keydown', this._windowKeydownHandler);
        }
    }

    dashboardData;
    dashboardDataError;
    wiredDashboardResult;

    @wire(getDashboardData, { dateRange: 'ALL' })
    wiredDashboardData(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboardData = data;
            this.dashboardDataError = undefined;
        } else if (error) {
            this.dashboardDataError = error;
            this.dashboardData = undefined;
            console.error('Error fetching dashboard data:', error);
        }
    }

    wiredHealthResult;
    @wire(getSystemHealth)
    wiredHealth(result) {
        this.wiredHealthResult = result;
        const { data, error } = result;
        if (data) {
            this.healthLabel = data.status || 'Unknown';
            this.healthTone = String(this.healthLabel).toLowerCase();
            this.criticalCount = data.activeIncidents || 0;
            return;
        }

        if (error) {
            this.healthLabel = 'Unknown';
            this.healthTone = 'unknown';
            this.criticalCount = 0;
        }
    }

    @wire(getUserContext)
    wiredUserContext({ data, error }) {
        if (data) {
            this.userName = data.userName;
            this.userProfile = data.userProfile;
            this.orgName = data.organizationName;
        }
    }

    updateTime() {
        this.currentTime = new Date().toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleEventClick(event) {
        const name = event.currentTarget.dataset.name;
        this.expandedEventName = this.expandedEventName === name ? '' : name;
    }

    navigate(event) {
        const requestedPage = event.currentTarget.dataset.page || 'command';
        this.currentPage = this.isPageEnabled(requestedPage) ? requestedPage : 'incidents';
        this.isSidebarOpen = false; // close mobile sidebar on navigation
    }

    async refreshView() {
        this.updateTime();
        this.dispatchEvent(new CustomEvent('refreshsentinelflowbeta'));
        
        this.isRefreshing = true;
        const promises = [];
        if (this.wiredDashboardResult) {
            promises.push(refreshApex(this.wiredDashboardResult));
        }
        if (this.wiredHealthResult) {
            promises.push(refreshApex(this.wiredHealthResult));
        }
        try {
            await Promise.all(promises);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Operations Command Center telemetry is up to date.',
                    variant: 'success'
                })
            );
        } catch (e) {
            console.error('Error refreshing telemetry:', e);
        } finally {
            this.isRefreshing = false;
        }
    }

    get showDashboardLoading() {
        return !this.dashboardData && !this.dashboardDataError;
    }

    get showDashboardError() {
        return !!this.dashboardDataError;
    }

    get dashboardErrorMessage() {
        if (!this.dashboardDataError) return '';
        if (Array.isArray(this.dashboardDataError?.body)) {
            return this.dashboardDataError.body.map((item) => item.message).join(', ');
        }
        return this.dashboardDataError?.body?.message || this.dashboardDataError?.message || 'Unable to load operations posture.';
    }

    get hasPendingApprovals() {
        return this.pendingApprovalRows && this.pendingApprovalRows.length > 0;
    }

    get hasRecentIncidents() {
        return this.recentIncidentRows && this.recentIncidentRows.length > 0;
    }

    get pageMeta() {
        return PAGE_META[this.currentPage] || PAGE_META.command;
    }

    get pageTitle() {
        return this.pageMeta.title;
    }

    get pageEyebrow() {
        return this.pageMeta.eyebrow;
    }

    get pageSummary() {
        return this.pageMeta.summary;
    }

    get healthClass() {
        return `health-chip ${this.healthTone}`;
    }

    get isCommunityEmbed() {
        return false;
    }

    get shellClass() {
        let cls = 'beta-shell';
        if (this.isCommunityEmbed) cls += ' community-embed';
        if (this.isDarkMode) cls += ' dark-theme';
        return cls;
    }

    get sidebarClass() {
        return this.isSidebarOpen ? 'sidebar mobile-open' : 'sidebar';
    }

    get themeIcon() {
        return this.isDarkMode ? 'utility:daylight' : 'utility:moon';
    }

    get themeToggleTitle() {
        return this.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode';
    }

    toggleTheme() {
        this.isDarkMode = !this.isDarkMode;
        this._applyThemeClass();
        try { localStorage.setItem('sf_theme', this.isDarkMode ? 'dark' : 'light'); } catch(e) { /* noop */ }
    }

    _applyThemeClass() {
        const hostEl = this.template.host;
        if (hostEl) {
            if (this.isDarkMode) {
                hostEl.classList.add('dark-theme');
            } else {
                hostEl.classList.remove('dark-theme');
            }
        }
    }

    toggleSidebar() {
        this.isSidebarOpen = !this.isSidebarOpen;
    }

    get orgMenuIcon() {
        return this.isOrgMenuOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    toggleOrgMenu() {
        this.isOrgMenuOpen = !this.isOrgMenuOpen;
    }

    handleMenuItemClick(event) {
        event.stopPropagation();
        this.isOrgMenuOpen = false;
        
        const actionName = event.currentTarget.dataset.action;

        if (actionName === 'logout') {
            const logoutUrl = '/secur/logout.jsp';
            window.location.href = logoutUrl;
        } else if (actionName === 'settings') {
            try {
                this[NavigationMixin.Navigate]({
                    type: 'standard__setup',
                    attributes: {
                        name: 'home'
                    }
                });
            } catch (e) {
                console.error(e);
            }
        } else if (actionName === 'switch_org') {
            // Open Salesforce login in a new tab to switch orgs
            window.open('https://login.salesforce.com', '_blank');
        }
    }

    get userInitials() {
        if (!this.userName || this.userName === 'Loading...') return '..';
        const parts = this.userName.trim().split(/\s+/);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return parts[0].substring(0, 2).toUpperCase();
    }

    get orgHealthScore() {
        return this.dashboardData && this.dashboardData.summary
            ? this.dashboardData.summary.orgHealthScore
            : 100;
    }

    get orgHealthLabel() {
        return this.dashboardData && this.dashboardData.summary
            ? this.dashboardData.summary.orgHealthStatus
            : 'Healthy';
    }

    get orgHealthCopy() {
        return this.dashboardData && this.dashboardData.summary
            ? this.dashboardData.summary.orgHealthReason
            : 'No active incidents are reducing the org health score.';
    }

    // Dynamic factors getters
    get systemHealthScore() {
        if (!this.dashboardData || !this.dashboardData.summary) return 90;
        const errs = this.dashboardData.summary.errorLogCount || 0;
        return Math.max(100 - errs * 2, 70);
    }

    get incidentImpactScore() {
        if (!this.dashboardData || !this.dashboardData.summary) return 70;
        const crits = this.dashboardData.summary.criticalIncidents || 0;
        return Math.max(100 - crits * 8, 40);
    }

    get responseEfficiencyScore() {
        if (!this.dashboardData || !this.dashboardData.summary) return 85;
        const confidence = this.dashboardData.summary.avgAiConfidence || 85;
        return confidence > 0 ? confidence : 85;
    }

    get approvalBacklogScore() {
        if (!this.dashboardData || !this.dashboardData.summary) return 80;
        const pending = this.dashboardData.summary.pendingApprovals || 0;
        return Math.max(100 - pending * 5, 50);
    }

    get healthScorePercentStyle() {
        return `--health-score-percent: ${this.orgHealthScore}%;`;
    }

    get pendingApprovalCount() {
        return this.dashboardData && this.dashboardData.summary
            ? this.dashboardData.summary.pendingApprovals
            : 0;
    }

    get kpiCards() {
        const d = this.dashboardData;
        if (!d || !d.summary) return [];
        return [
            { label: 'Open Incidents', value: d.summary.totalIncidents, trend: '12% vs last 7 days', icon: 'utility:warning', iconClass: 'kpi-icon blue', trendClass: 'trend up' },
            { label: 'Critical Incidents', value: d.summary.criticalIncidents, trend: 'Needs attention', icon: 'utility:error', iconClass: 'kpi-icon red', trendClass: 'trend down' },
            { label: 'Pending Approvals', value: d.summary.pendingApprovals, trend: 'Human review', icon: 'utility:approval', iconClass: 'kpi-icon amber', trendClass: 'trend down' },
            { label: 'Executed Actions', value: d.summary.executedActions, trend: '18% vs last 7 days', icon: 'utility:bolt', iconClass: 'kpi-icon green', trendClass: 'trend up' },
            { label: 'Cases Created', value: d.summary.recentCasesCreated, trend: '5 vs last 7 days', icon: 'utility:case', iconClass: 'kpi-icon purple', trendClass: 'trend up' }
        ];
    }

    // --- Approval Queue Sorting, Filtering, and Pagination ---
    get riskFilterOptions() {
        return [
            { label: 'All Risks', value: 'ALL' },
            { label: 'Critical', value: 'Critical' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    handleApprovalFilterRiskChange(event) {
        this.approvalFilterRisk = event.target.value;
        this.approvalPage = 1;
    }

    handleApprovalSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.approvalSortField === field) {
            this.approvalSortAsc = !this.approvalSortAsc;
        } else {
            this.approvalSortField = field;
            this.approvalSortAsc = true;
        }
        this.approvalPage = 1;
    }

    handleApprovalPrev() {
        if (this.approvalPage > 1) {
            this.approvalPage--;
        }
    }

    handleApprovalNext() {
        if (this.approvalPage < this.approvalTotalPages) {
            this.approvalPage++;
        }
    }

    get filteredApprovals() {
        if (!this.dashboardData || !this.dashboardData.pendingApprovals) return [];
        let rows = this.dashboardData.pendingApprovals.map(inc => ({
            id: inc.name || inc.id,
            type: inc.incidentType || 'Action',
            action: inc.runbookKey || inc.executionAction || 'Autonomous Remediation',
            risk: inc.riskLevel || 'Low',
            riskClass: 'risk-pill ' + (inc.riskLevel ? inc.riskLevel.toLowerCase() : 'low')
        }));

        if (this.searchKey) {
            const sk = this.searchKey.toLowerCase();
            rows = rows.filter(r => 
                (r.id && r.id.toLowerCase().includes(sk)) || 
                (r.type && r.type.toLowerCase().includes(sk)) || 
                (r.action && r.action.toLowerCase().includes(sk)) || 
                (r.risk && r.risk.toLowerCase().includes(sk))
            );
        }

        if (this.approvalFilterRisk !== 'ALL') {
            rows = rows.filter(r => r.risk && r.risk.toLowerCase() === this.approvalFilterRisk.toLowerCase());
        }

        const field = this.approvalSortField;
        const asc = this.approvalSortAsc;
        rows.sort((a, b) => {
            let valA = a[field] || '';
            let valB = b[field] || '';
            if (typeof valA === 'string') {
                return asc ? valA.localeCompare(valB) : valB.localeCompare(valA);
            }
            return asc ? (valA > valB ? 1 : -1) : (valB > valA ? 1 : -1);
        });

        return rows;
    }

    get pendingApprovalRows() {
        const rows = this.filteredApprovals;
        const start = (this.approvalPage - 1) * this.approvalPageSize;
        return rows.slice(start, start + this.approvalPageSize);
    }

    get approvalTotalPages() {
        return Math.ceil(this.filteredApprovals.length / this.approvalPageSize) || 1;
    }

    get isApprovalPrevDisabled() {
        return this.approvalPage <= 1;
    }

    get isApprovalNextDisabled() {
        return this.approvalPage >= this.approvalTotalPages;
    }

    get approvalSortIdArrow() { return this.getSortArrow('id', this.approvalSortField, this.approvalSortAsc); }
    get approvalSortTypeArrow() { return this.getSortArrow('type', this.approvalSortField, this.approvalSortAsc); }
    get approvalSortActionArrow() { return this.getSortArrow('action', this.approvalSortField, this.approvalSortAsc); }
    get approvalSortRiskArrow() { return this.getSortArrow('risk', this.approvalSortField, this.approvalSortAsc); }

    // --- Recent Incidents Sorting, Filtering, and Pagination ---
    handleIncidentFilterRiskChange(event) {
        this.incidentFilterRisk = event.target.value;
        this.incidentPage = 1;
    }

    handleIncidentFilterStatusChange(event) {
        this.incidentFilterStatus = event.target.value;
        this.incidentPage = 1;
    }

    handleIncidentFilterEnvChange(event) {
        this.incidentFilterEnv = event.target.value;
        this.incidentPage = 1;
    }

    handleIncidentSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.incidentSortField === field) {
            this.incidentSortAsc = !this.incidentSortAsc;
        } else {
            this.incidentSortField = field;
            this.incidentSortAsc = true;
        }
        this.incidentPage = 1;
    }

    handleIncidentPrev() {
        if (this.incidentPage > 1) {
            this.incidentPage--;
        }
    }

    handleIncidentNext() {
        if (this.incidentPage < this.incidentTotalPages) {
            this.incidentPage++;
        }
    }

    get filteredIncidents() {
        if (!this.dashboardData || !this.dashboardData.recentIncidents) return [];
        let rows = this.dashboardData.recentIncidents.map(inc => ({
            id: inc.name || inc.id,
            type: inc.incidentType || 'Action',
            env: inc.environment ? inc.environment.charAt(0).toUpperCase() + inc.environment.slice(1).toLowerCase() : 'Sandbox',
            envClass: 'env-pill ' + (inc.environment ? inc.environment.toLowerCase() : 'sandbox'),
            risk: inc.riskLevel || 'Low',
            riskClass: 'risk-pill ' + (inc.riskLevel ? inc.riskLevel.toLowerCase() : 'low'),
            status: inc.status || 'Open',
            statusClass: 'status-pill ' + (inc.status ? inc.status.toLowerCase().replace(' ', '-') : 'open'),
            runbook: inc.runbookKey || 'N/A'
        }));

        if (this.searchKey) {
            const sk = this.searchKey.toLowerCase();
            rows = rows.filter(r => 
                (r.id && r.id.toLowerCase().includes(sk)) || 
                (r.type && r.type.toLowerCase().includes(sk)) || 
                (r.env && r.env.toLowerCase().includes(sk)) || 
                (r.risk && r.risk.toLowerCase().includes(sk)) || 
                (r.status && r.status.toLowerCase().includes(sk)) || 
                (r.runbook && r.runbook.toLowerCase().includes(sk))
            );
        }

        if (this.incidentFilterRisk !== 'ALL') {
            rows = rows.filter(r => r.risk && r.risk.toLowerCase() === this.incidentFilterRisk.toLowerCase());
        }

        if (this.incidentFilterStatus !== 'ALL') {
            rows = rows.filter(r => r.status && r.status.toLowerCase() === this.incidentFilterStatus.toLowerCase());
        }

        if (this.incidentFilterEnv !== 'ALL') {
            rows = rows.filter(r => r.env && r.env.toLowerCase() === this.incidentFilterEnv.toLowerCase());
        }

        const field = this.incidentSortField;
        const asc = this.incidentSortAsc;
        rows.sort((a, b) => {
            let valA = a[field] || '';
            let valB = b[field] || '';
            if (typeof valA === 'string') {
                return asc ? valA.localeCompare(valB) : valB.localeCompare(valA);
            }
            return asc ? (valA > valB ? 1 : -1) : (valB > valA ? 1 : -1);
        });

        return rows;
    }

    get recentIncidentRows() {
        const rows = this.filteredIncidents;
        const start = (this.incidentPage - 1) * this.incidentPageSize;
        return rows.slice(start, start + this.incidentPageSize);
    }

    get incidentTotalPages() {
        return Math.ceil(this.filteredIncidents.length / this.incidentPageSize) || 1;
    }

    get isIncidentPrevDisabled() {
        return this.incidentPage <= 1;
    }

    get isIncidentNextDisabled() {
        return this.incidentPage >= this.incidentTotalPages;
    }

    get incidentSortIdArrow() { return this.getSortArrow('id', this.incidentSortField, this.incidentSortAsc); }
    get incidentSortTypeArrow() { return this.getSortArrow('type', this.incidentSortField, this.incidentSortAsc); }
    get incidentSortEnvArrow() { return this.getSortArrow('env', this.incidentSortField, this.incidentSortAsc); }
    get incidentSortRiskArrow() { return this.getSortArrow('risk', this.incidentSortField, this.incidentSortAsc); }
    get incidentSortStatusArrow() { return this.getSortArrow('status', this.incidentSortField, this.incidentSortAsc); }
    get incidentSortRunbookArrow() { return this.getSortArrow('runbook', this.incidentSortField, this.incidentSortAsc); }

    getSortArrow(field, currentField, isAsc) {
        if (currentField !== field) return ' ↕';
        return isAsc ? ' ▲' : ' ▼';
    }

    // --- Quick Governance Review Modal Handlers ---
    openReviewModalFromRow(event) {
        if (event.target.tagName === 'A' || event.target.closest('a')) {
            return;
        }
        const requestId = event.currentTarget.dataset.id;
        const row = this.filteredApprovals.find(r => r.id === requestId);
        if (row) {
            this.selectedReviewRow = row;
            this.approvalApproverName = '';
            this.rejectionReason = '';
            this.isApproving = true;
            this.isReviewModalOpen = true;
        }
    }

    openReviewModalFromButton(event) {
        event.stopPropagation();
        const requestId = event.currentTarget.dataset.id;
        const row = this.filteredApprovals.find(r => r.id === requestId);
        if (row) {
            this.selectedReviewRow = row;
            this.approvalApproverName = '';
            this.rejectionReason = '';
            this.isApproving = true;
            this.isReviewModalOpen = true;
        }
    }

    closeReviewModal() {
        this.isReviewModalOpen = false;
        this.selectedReviewRow = null;
    }

    toggleApprovalMode() {
        this.isApproving = !this.isApproving;
    }

    handleApproverNameChange(event) {
        this.approvalApproverName = event.target.value;
    }

    handleRejectionReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    get isSubmitApprovalDisabled() {
        return !this.approvalApproverName || this.approvalApproverName.trim() === '';
    }

    get isSubmitRejectionDisabled() {
        return !this.rejectionReason || this.rejectionReason.trim() === '';
    }

    async submitApproval() {
        if (this.isSubmitApprovalDisabled) return;
        const incidentId = this.selectedReviewRow.id;
        const approverName = this.approvalApproverName;
        
        this.closeReviewModal();
        this.dashboardData = null; // show loading skeleton
        
        try {
            const res = await approveWorkflow({ incidentId: incidentId, approvedBy: approverName });
            const data = JSON.parse(res);
            if (data.error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Approval Failed',
                        message: data.error,
                        variant: 'error'
                    })
                );
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Governance Action Approved',
                        message: `Action for ${incidentId} approved by ${approverName} and scheduled for execution.`,
                        variant: 'success'
                    })
                );
            }
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'System Error',
                    message: e.message,
                    variant: 'error'
                })
            );
        } finally {
            if (this.wiredDashboardResult) {
                await refreshApex(this.wiredDashboardResult);
            }
        }
    }

    async submitRejection() {
        if (this.isSubmitRejectionDisabled) return;
        const incidentId = this.selectedReviewRow.id;
        const reason = this.rejectionReason;
        
        this.closeReviewModal();
        this.dashboardData = null; // show loading skeleton
        
        try {
            const res = await rejectWorkflow({ incidentId: incidentId, reason: reason });
            const data = JSON.parse(res);
            if (data.error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Rejection Failed',
                        message: data.error,
                        variant: 'error'
                    })
                );
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Recommendation Rejected',
                        message: `Action suggestion for ${incidentId} has been rejected.`,
                        variant: 'info'
                    })
                );
            }
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'System Error',
                    message: e.message,
                    variant: 'error'
                })
            );
        } finally {
            if (this.wiredDashboardResult) {
                await refreshApex(this.wiredDashboardResult);
            }
        }
    }

    get latestCriticalIncident() {
        return this.dashboardData ? this.dashboardData.latestCriticalIncident : null;
    }

    get timelineEvents() {
        const list = (this.dashboardData && this.dashboardData.recentReplayEvents && this.dashboardData.recentReplayEvents.length > 0)
            ? this.dashboardData.recentReplayEvents.map(evt => {
                const timeStr = evt.createdDate ? new Date(evt.createdDate).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
                return {
                    name: evt.eventType || 'Event Processed',
                    time: timeStr,
                    details: (evt.decision ? `Decision: ${evt.decision}. ` : '') + (evt.reason || 'No decision telemetry.'),
                    icon: evt.decision === 'Rejected' ? 'utility:error' : 'utility:success'
                };
            })
            : [
                { name: 'Incident Ingestion', time: '10:14 AM', details: 'Incident data verified and stored in database.', icon: 'utility:success' },
                { name: 'Risk Calculation', time: '10:14 AM', details: 'Risk score evaluated at 7.2 based on priority.', icon: 'utility:success' },
                { name: 'Policy Evaluation', time: '10:14 AM', details: 'Policy gate triggered: Approval required.', icon: 'utility:success' },
                { name: 'AI Recommendation', time: '10:14 AM', details: 'Zentom AI recommended: Runbook RB-PAY-007.', icon: 'utility:success' }
            ];
        
        return list.map(item => ({
            ...item,
            isExpanded: this.expandedEventName === item.name
        }));
    }

    get systemHealthRows() {
        const errorCount = this.dashboardData && this.dashboardData.summary
            ? this.dashboardData.summary.errorLogCount
            : 0;
        
        let apiStatusClass, apiStatusText, apiValueClass, apiValueText;
        if (errorCount > 20) {
            apiStatusClass = 'status-critical';
            apiStatusText = 'Experiencing high load';
            apiValueClass = 'value-critical';
            apiValueText = '92.15%';
        } else if (errorCount > 5) {
            apiStatusClass = 'status-warn';
            apiStatusText = 'Slightly elevated latency';
            apiValueClass = 'value-warn';
            apiValueText = '98.42%';
        } else {
            apiStatusClass = 'status-ok';
            apiStatusText = 'All systems operational';
            apiValueClass = 'value-ok';
            apiValueText = '99.98%';
        }

        let dbStatusClass, dbStatusText, dbValueClass, dbValueText;
        if (errorCount > 30) {
            dbStatusClass = 'status-critical';
            dbStatusText = 'Database pool exhausted';
            dbValueClass = 'value-critical';
            dbValueText = '97.20%';
        } else if (errorCount > 10) {
            dbStatusClass = 'status-warn';
            dbStatusText = 'High connection usage';
            dbValueClass = 'value-warn';
            dbValueText = '99.12%';
        } else {
            dbStatusClass = 'status-ok';
            dbStatusText = 'All systems operational';
            dbValueClass = 'value-ok';
            dbValueText = '99.95%';
        }

        let errStatusClass, errStatusText, errValueClass, errValueText;
        if (errorCount > 15) {
            errStatusClass = 'status-critical';
            errStatusText = 'Errors detected';
            errValueClass = 'value-critical';
            errValueText = String(errorCount);
        } else if (errorCount > 0) {
            errStatusClass = 'status-warn';
            errStatusText = 'System warnings';
            errValueClass = 'value-warn';
            errValueText = String(errorCount);
        } else {
            errStatusClass = 'status-ok';
            errStatusText = 'No critical errors';
            errValueClass = 'value-ok';
            errValueText = '0';
        }
        
        return [
            { 
                name: 'API', 
                status: apiStatusText, 
                value: apiValueText, 
                icon: 'utility:world',
                statusClass: apiStatusClass,
                valueClass: apiValueClass
            },
            { 
                name: 'Database', 
                status: dbStatusText, 
                value: dbValueText, 
                icon: 'utility:database',
                statusClass: dbStatusClass,
                valueClass: dbValueClass
            },
            { 
                name: 'Error Log', 
                status: errStatusText, 
                value: errValueText, 
                icon: 'utility:record',
                statusClass: errStatusClass,
                valueClass: errValueClass
            }
        ];
    }

    get isCommand() {
        return this.currentPage === 'command';
    }

    get isApprovals() {
        return this.currentPage === 'approvals';
    }

    get isAnalytics() {
        return this.currentPage === 'analytics';
    }

    get isCopilot() {
        return this.currentPage === 'copilot';
    }

    get isIncidents() {
        return this.currentPage === 'incidents';
    }

    get isSettings() {
        return this.currentPage === 'settings';
    }

    get commandNavClass() {
        return this.navClass('command');
    }

    get approvalsNavClass() {
        return this.navClass('approvals');
    }

    get analyticsNavClass() {
        return this.navClass('analytics');
    }

    get copilotNavClass() {
        return this.navClass('copilot');
    }

    get incidentsNavClass() {
        return this.navClass('incidents');
    }

    get settingsNavClass() {
        return this.navClass('settings');
    }

    get actionsNavClass() {
        return this.navClass('actions');
    }

    get showRunbooks() {
        return FUTURE_MODULE_FLAGS.showRunbooks;
    }

    get showPolicies() {
        return FUTURE_MODULE_FLAGS.showPolicies;
    }

    get showCases() {
        return FUTURE_MODULE_FLAGS.showCases;
    }

    get runbooksNavClass() {
        return this.navClass('runbooks');
    }

    get policiesNavClass() {
        return this.navClass('policies');
    }

    get casesNavClass() {
        return this.navClass('cases');
    }

    get reportsNavClass() {
        return this.navClass('reports');
    }

    get integrationsNavClass() {
        return this.navClass('integrations');
    }

    get isActions() {
        return this.currentPage === 'actions';
    }

    get isRunbooks() {
        return this.showRunbooks && this.currentPage === 'runbooks';
    }

    get isPolicies() {
        return this.showPolicies && this.currentPage === 'policies';
    }

    get isCases() {
        return this.showCases && this.currentPage === 'cases';
    }

    get isReports() {
        return this.currentPage === 'reports';
    }

    get isIntegrations() {
        return this.currentPage === 'integrations';
    }

    navClass(pageName) {
        return this.currentPage === pageName ? 'nav-item active' : 'nav-item';
    }

    isPageEnabled(pageName) {
        if (!DISABLED_FUTURE_PAGES.has(pageName)) {
            return true;
        }
        if (pageName === 'cases') {
            return this.showCases;
        }
        if (pageName === 'policies') {
            return this.showPolicies;
        }
        if (pageName === 'runbooks') {
            return this.showRunbooks;
        }
        return false;
    }
}
