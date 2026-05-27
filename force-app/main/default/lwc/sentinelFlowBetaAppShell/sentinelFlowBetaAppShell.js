import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import basePath from '@salesforce/community/basePath';
import getSystemHealth from '@salesforce/apex/SystemMonitorController.getSystemHealth';
import getUserContext from '@salesforce/apex/SystemMonitorController.getUserContext';
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

    clock;

    connectedCallback() {
        this.updateTime();
        this.clock = setInterval(() => this.updateTime(), 30000);
        try {
            const saved = localStorage.getItem('sf_theme');
            if (saved === 'light') this.isDarkMode = false;
            else if (saved === 'dark') this.isDarkMode = true;
        } catch(e) { /* noop */ }
    }

    _themeApplied = false;
    renderedCallback() {
        this._applyThemeClass();
    }

    disconnectedCallback() {
        if (this.clock) {
            clearInterval(this.clock);
        }
    }

    @wire(getSystemHealth)
    wiredHealth({ data, error }) {
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

    navigate(event) {
        this.currentPage = event.currentTarget.dataset.page || 'command';
    }

    refreshView() {
        this.updateTime();
        this.dispatchEvent(new CustomEvent('refreshsentinelflowbeta'));
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
        return Boolean(basePath);
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
            const logoutUrl = basePath ? `${basePath}/secur/logout.jsp` : '/secur/logout.jsp';
            window.location.href = logoutUrl;
        } else if (actionName === 'settings') {
            try {
                if (basePath) {
                    // We are in a community, so we need to guess the internal lightning URL
                    let host = window.location.hostname;
                    if (host.includes('.my.site.com')) {
                        host = host.replace('.my.site.com', '.lightning.force.com');
                    }
                    window.open(`https://${host}/lightning/setup/SetupOneHome/home`, '_blank');
                } else {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__setup',
                        attributes: {
                            name: 'home'
                        }
                    });
                }
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
        return this.healthTone === 'critical' ? 72 : 87;
    }

    get orgHealthLabel() {
        return this.healthTone === 'critical' ? 'Watch' : 'Healthy';
    }

    get orgHealthCopy() {
        return this.healthTone === 'critical'
            ? 'Critical incidents are active. Review approvals and replay evidence before action.'
            : 'Your org is healthy. No critical risks detected. Keep monitoring.';
    }

    get pendingApprovalCount() {
        return this.criticalCount > 0 ? Math.min(this.criticalCount, 9) : 6;
    }

    get kpiCards() {
        const critical = this.criticalCount || 4;
        return [
            {
                label: 'Open Incidents',
                value: critical + 12,
                trend: '12% vs last 7 days',
                icon: 'utility:warning',
                iconClass: 'kpi-icon blue',
                trendClass: 'trend up'
            },
            {
                label: 'Critical Incidents',
                value: critical,
                trend: 'Needs attention',
                icon: 'utility:error',
                iconClass: 'kpi-icon red',
                trendClass: 'trend down'
            },
            {
                label: 'Pending Approvals',
                value: this.pendingApprovalCount,
                trend: 'Human review',
                icon: 'utility:approval',
                iconClass: 'kpi-icon amber',
                trendClass: 'trend down'
            },
            {
                label: 'Executed Actions',
                value: 42,
                trend: '18% vs last 7 days',
                icon: 'utility:bolt',
                iconClass: 'kpi-icon green',
                trendClass: 'trend up'
            },
            {
                label: 'Cases Created',
                value: 19,
                trend: '5 vs last 7 days',
                icon: 'utility:case',
                iconClass: 'kpi-icon purple',
                trendClass: 'trend up'
            }
        ];
    }

    get pendingApprovalRows() {
        return [
            {
                id: 'APR-2025-000231',
                type: 'Runbook',
                action: 'RB-PAY-007 - Restart Payment Service',
                risk: 'High',
                riskClass: 'risk-pill high'
            },
            {
                id: 'APR-2025-000230',
                type: 'Action',
                action: 'Scale APP-SVC-02',
                risk: 'Medium',
                riskClass: 'risk-pill medium'
            },
            {
                id: 'APR-2025-000229',
                type: 'Runbook',
                action: 'RB-CACHE-003 - Clear Redis Cache',
                risk: 'Low',
                riskClass: 'risk-pill low'
            }
        ];
    }

    get recentIncidentRows() {
        return [
            {
                id: 'INC-2025-00123',
                type: 'API Rate Limit',
                env: 'Production',
                risk: 'Medium',
                riskClass: 'risk-pill medium',
                status: 'In Progress',
                statusClass: 'status-pill progress',
                runbook: 'API Rate Limit Runbook'
            },
            {
                id: 'INC-2025-00122',
                type: 'Workflow Failure',
                env: 'Production',
                risk: 'Low',
                riskClass: 'risk-pill low',
                status: 'Resolved',
                statusClass: 'status-pill resolved',
                runbook: 'Workflow Failure Runbook'
            },
            {
                id: 'INC-2025-00120',
                type: 'Login Anomaly',
                env: 'Sandbox',
                risk: 'High',
                riskClass: 'risk-pill high',
                status: 'Resolved',
                statusClass: 'status-pill resolved',
                runbook: 'Login Anomaly Runbook'
            }
        ];
    }

    get timelineEvents() {
        return [
            { name: 'Incident Received', time: '10:14 AM' },
            { name: 'Risk Calculated', time: '10:14 AM' },
            { name: 'Policy Evaluated', time: '10:14 AM' },
            { name: 'AI Recommendation Generated', time: '10:14 AM' },
            { name: 'Human Approved', time: '10:16 AM' },
            { name: 'Case Created', time: '10:16 AM' }
        ];
    }

    get systemHealthRows() {
        return [
            { name: 'API', status: 'All systems operational', value: '99.98%', icon: 'utility:world' },
            { name: 'Database', status: 'All systems operational', value: '99.95%', icon: 'utility:database' },
            { name: 'Error Log', status: 'No critical errors', value: '0', icon: 'utility:record' }
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
        return this.currentPage === 'runbooks';
    }

    get isPolicies() {
        return this.currentPage === 'policies';
    }

    get isCases() {
        return this.currentPage === 'cases';
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
}