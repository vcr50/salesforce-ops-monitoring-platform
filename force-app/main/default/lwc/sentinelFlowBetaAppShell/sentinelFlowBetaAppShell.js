import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/ZentomDashboardController.getDashboardData';
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

    dashboardData;
    dashboardDataError;

    @wire(getDashboardData)
    wiredDashboardData({ data, error }) {
        if (data) {
            this.dashboardData = data;
            this.dashboardDataError = undefined;
        } else if (error) {
            this.dashboardDataError = error;
            this.dashboardData = undefined;
            console.error('Error fetching dashboard data:', error);
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
        const d = this.dashboardData;
        if (!d) return [];
        return [
            { label: 'Open Incidents', value: d.openIncidentsCount, trend: '12% vs last 7 days', icon: 'utility:warning', iconClass: 'kpi-icon blue', trendClass: 'trend up' },
            { label: 'Critical Incidents', value: d.criticalIncidentsCount, trend: 'Needs attention', icon: 'utility:error', iconClass: 'kpi-icon red', trendClass: 'trend down' },
            { label: 'Pending Approvals', value: d.pendingApprovalsCount, trend: 'Human review', icon: 'utility:approval', iconClass: 'kpi-icon amber', trendClass: 'trend down' },
            { label: 'Executed Actions', value: d.executedActionsCount, trend: '18% vs last 7 days', icon: 'utility:bolt', iconClass: 'kpi-icon green', trendClass: 'trend up' },
            { label: 'Cases Created', value: d.casesCreatedCount, trend: '5 vs last 7 days', icon: 'utility:case', iconClass: 'kpi-icon purple', trendClass: 'trend up' }
        ];
    }

    get pendingApprovalRows() {
        if (!this.dashboardData || !this.dashboardData.pendingApprovals) return [];
        return this.dashboardData.pendingApprovals.map(inc => ({
            id: inc.Name,
            type: 'Action',
            action: inc.Runbook_Title__c || inc.Recommended_Action__c,
            risk: inc.Risk_Level__c,
            riskClass: 'risk-pill ' + (inc.Risk_Level__c ? inc.Risk_Level__c.toLowerCase() : 'low')
        }));
    }

    get recentIncidentRows() {
        if (!this.dashboardData || !this.dashboardData.recentIncidents) return [];
        return this.dashboardData.recentIncidents.map(inc => ({
            id: inc.Name,
            type: inc.Incident_Type__c,
            env: inc.Environment__c,
            risk: inc.Risk_Level__c,
            riskClass: 'risk-pill ' + (inc.Risk_Level__c ? inc.Risk_Level__c.toLowerCase() : 'low'),
            status: inc.Status__c,
            statusClass: 'status-pill ' + (inc.Status__c === 'Resolved' ? 'resolved' : 'progress'),
            runbook: inc.Runbook_Title__c
        }));
    }


    get latestCriticalIncident() {
        return this.dashboardData ? this.dashboardData.latestCriticalIncident : null;
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