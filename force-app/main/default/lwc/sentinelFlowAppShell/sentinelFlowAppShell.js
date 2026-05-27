import { LightningElement, track, wire } from 'lwc';
import getSystemHealth from '@salesforce/apex/SystemMonitorController.getSystemHealth';
import sentinelFlowLogo from '@salesforce/resourceUrl/sentinelFlowLogo';

const PAGE_META = {
    home: {
        title: 'Guardian Home',
        eyebrow: 'What matters right now',
        summary: 'Health, revenue risk, and AI actions'
    },
    incidents: {
        title: 'Incidents',
        eyebrow: 'Operational queue',
        summary: 'Prioritize, inspect, and remediate'
    },
    integrations: {
        title: 'Integrations',
        eyebrow: 'Connected systems',
        summary: 'API status and recent sync health'
    },
    impact: {
        title: 'Business Impact',
        eyebrow: 'Revenue and users',
        summary: 'Quantified incident impact'
    },
    copilot: {
        title: 'Zentom Mission Control',
        eyebrow: 'Zentom AI Engine',
        summary: 'Ask, analyze, remediate, and summarize'
    },
    workflow: {
        title: 'Workflow Map',
        eyebrow: 'Operations Flow',
        summary: 'Visualizing system processes'
    },
    compliance: {
        title: 'Compliance Dashboard',
        eyebrow: 'Governance',
        summary: 'Security and compliance checks'
    },
    founder: {
        title: 'Founder Mode',
        eyebrow: 'Executive Overview',
        summary: 'High-level business metrics'
    },
    settings: {
        title: 'Settings',
        eyebrow: 'Configuration',
        summary: 'Controls and preferences'
    }
};

export default class SentinelFlowAppShell extends LightningElement {
    logoUrl = sentinelFlowLogo;
    @track currentPage = 'home';
    @track currentTime = '';
    @track healthLabel = 'Checking';
    @track healthTone = 'checking';
    @track criticalCount = 0;
    @track theme = 'dark';

    _clock;

    connectedCallback() {
        this.updateTime();
        this._clock = setInterval(() => this.updateTime(), 1000);
    }

    disconnectedCallback() {
        if (this._clock) {
            clearInterval(this._clock);
        }
    }

    @wire(getSystemHealth)
    wiredHealth({ data, error }) {
        if (data) {
            this.healthLabel = data.status || 'Unknown';
            this.healthTone = String(this.healthLabel).toLowerCase();
            this.criticalCount = data.activeIncidents || 0;
        } else if (error) {
            this.healthLabel = 'Unknown';
            this.healthTone = 'unknown';
            this.criticalCount = 0;
        }
    }

    updateTime() {
        this.currentTime = new Date().toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    navigate(event) {
        const page = event.currentTarget.dataset.page;
        if (page) {
            this.currentPage = page;
        }
    }

    refreshView() {
        this.dispatchEvent(new CustomEvent('refreshsentinelflow'));
        this.updateTime();
    }

    toggleTheme() {
        this.theme = this.theme === 'dark' ? 'light' : 'dark';
    }

    get shellClass() {
        return `app-shell tailwind-inspired ${this.theme === 'dark' ? 'theme-dark' : 'theme-light'}`;
    }

    get themeIcon() {
        return this.theme === 'dark' ? 'utility:dayview' : 'utility:dark_mode';
    }

    get themeLabel() {
        return this.theme === 'dark' ? 'Day' : 'Dark';
    }

    get themeToggleClass() {
        return `theme-toggle ${this.theme === 'dark' ? 'is-dark' : 'is-light'}`;
    }

    get themeToggleTitle() {
        return this.theme === 'dark' ? 'Switch to day mode' : 'Switch to dark mode';
    }

    get pageMeta() {
        return PAGE_META[this.currentPage] || PAGE_META.home;
    }

    get pageTitle() {
        return this.pageMeta.title;
    }

    get pageEyebrow() {
        return this.pageMeta.eyebrow;
    }

    get toolbarSummary() {
        return this.pageMeta.summary;
    }

    get isHome() {
        return this.currentPage === 'home';
    }

    get isIncidents() {
        return this.currentPage === 'incidents';
    }

    get isIntegrations() {
        return this.currentPage === 'integrations';
    }

    get isImpact() {
        return this.currentPage === 'impact';
    }

    get isCopilot() {
        return this.currentPage === 'copilot';
    }

    get isWorkflow() {
        return this.currentPage === 'workflow';
    }

    get isCompliance() {
        return this.currentPage === 'compliance';
    }

    get isFounder() {
        return this.currentPage === 'founder';
    }

    get isSettings() {
        return this.currentPage === 'settings';
    }

    get homeNavClass() {
        return this.currentPage === 'home' ? 'nav-item active' : 'nav-item';
    }

    get incidentsNavClass() {
        return this.currentPage === 'incidents' ? 'nav-item active' : 'nav-item';
    }

    get integrationsNavClass() {
        return this.currentPage === 'integrations' ? 'nav-item active' : 'nav-item';
    }

    get impactNavClass() {
        return this.currentPage === 'impact' ? 'nav-item active' : 'nav-item';
    }

    get copilotNavClass() {
        return this.currentPage === 'copilot' ? 'nav-item active' : 'nav-item';
    }

    get workflowNavClass() {
        return this.currentPage === 'workflow' ? 'nav-item active' : 'nav-item';
    }

    get complianceNavClass() {
        return this.currentPage === 'compliance' ? 'nav-item active' : 'nav-item';
    }

    get founderNavClass() {
        return this.currentPage === 'founder' ? 'nav-item active' : 'nav-item';
    }

    get settingsNavClass() {
        return this.currentPage === 'settings' ? 'nav-item active' : 'nav-item';
    }
}