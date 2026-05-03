import { LightningElement, track } from 'lwc';
import sentinelFlowLogo from '@salesforce/resourceUrl/sentinelFlowLogo';

export default class SentinelFlowPortalApp extends LightningElement {
    logoUrl = sentinelFlowLogo;
    @track currentPage = 'home';
    @track currentTime = '';
    
    _timer;

    connectedCallback() {
        this.updateTime();
        this._timer = setInterval(() => {
            this.updateTime();
        }, 1000);
    }

    disconnectedCallback() {
        if (this._timer) {
            clearInterval(this._timer);
        }
    }

    updateTime() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    navigate(event) {
        const page = event.currentTarget.dataset.page;
        if (page) {
            this.currentPage = page;
        }
    }

    // --- State Getters ---
    get isHome() { return this.currentPage === 'home'; }
    get isIncidents() { return this.currentPage === 'incidents'; }
    get isIntegrations() { return this.currentPage === 'integrations'; }
    get isImpact() { return this.currentPage === 'impact'; }
    get isCopilot() { return this.currentPage === 'copilot'; }
    get isSettings() { return this.currentPage === 'settings'; }

    // --- Nav Class Getters ---
    get getNavClassHome() { return this.currentPage === 'home' ? 'nav-item active' : 'nav-item'; }
    get getNavClassIncidents() { return this.currentPage === 'incidents' ? 'nav-item active' : 'nav-item'; }
    get getNavClassIntegrations() { return this.currentPage === 'integrations' ? 'nav-item active' : 'nav-item'; }
    get getNavClassImpact() { return this.currentPage === 'impact' ? 'nav-item active' : 'nav-item'; }
    get getNavClassCopilot() { return this.currentPage === 'copilot' ? 'nav-item active' : 'nav-item'; }
    get getNavClassSettings() { return this.currentPage === 'settings' ? 'nav-item active' : 'nav-item'; }
}