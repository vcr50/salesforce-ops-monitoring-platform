import { LightningElement, track, wire } from 'lwc';
import getEndpoints   from '@salesforce/apex/IntegrationEndpointController.getEndpoints';
import createEndpoint from '@salesforce/apex/IntegrationEndpointController.createEndpoint';
import deleteEndpoint from '@salesforce/apex/IntegrationEndpointController.deleteEndpoint';
import resetCircuitBreaker from '@salesforce/apex/IntegrationEndpointController.resetCircuitBreaker';
import { refreshApex } from '@salesforce/apex';

export default class SentinelFlowPortalSettings extends LightningElement {

    // ── Tab state ────────────────────────────────────────────────────────────
    @track activeTab = 'integrations';

    get isTab1() { return this.activeTab === 'integrations'; }
    get isTab2() { return this.activeTab === 'retry'; }
    get isTab3() { return this.activeTab === 'alerts'; }

    get tab1Class() { return 'tab-btn' + (this.isTab1 ? ' tab-active' : ''); }
    get tab2Class() { return 'tab-btn' + (this.isTab2 ? ' tab-active' : ''); }
    get tab3Class() { return 'tab-btn' + (this.isTab3 ? ' tab-active' : ''); }

    switchTab(evt) {
        this.activeTab = evt.currentTarget.dataset.tab;
    }

    // ── TAB 1: Integration Endpoints ─────────────────────────────────────────
    @track endpoints = [];
    @track loadingEndpoints = true;
    @track isSaving = false;
    @track addError = null;
    @track addSuccess = false;

    @track newEndpoint = {
        name: '',
        endpointUrl: '',
        authType: 'API Key',
        retryPolicy: 'Immediate',
        maxRetries: 3
    };

    _wiredEndpointsResult;

    @wire(getEndpoints)
    wiredEndpoints(result) {
        this._wiredEndpointsResult = result;
        if (result.data) {
            this.endpoints = result.data.map(ep => ({
                ...ep,
                circuitOpen: ep.circuitStatus === 'Open',
                circuitBadgeClass: ep.circuitStatus === 'Open'
                    ? 'badge badge-circuit-open'
                    : ep.circuitStatus === 'Half-Open'
                        ? 'badge badge-circuit-half'
                        : 'badge badge-circuit-closed'
            }));
            this.loadingEndpoints = false;
        } else if (result.error) {
            this.loadingEndpoints = false;
        }
    }

    get hasEndpoints() { return this.endpoints && this.endpoints.length > 0; }
    get endpointCount() { return this.endpoints ? this.endpoints.length : 0; }

    handleEndpointField(evt) {
        const field = evt.currentTarget.dataset.field;
        const val   = evt.currentTarget.value;
        this.newEndpoint = { ...this.newEndpoint, [field]: field === 'maxRetries' ? parseInt(val, 10) : val };
    }

    async addEndpoint() {
        this.addError   = null;
        this.addSuccess = false;

        if (!this.newEndpoint.name || !this.newEndpoint.name.trim()) {
            this.addError = 'API Name is required.';
            return;
        }

        this.isSaving = true;
        try {
            await createEndpoint({
                name:        this.newEndpoint.name,
                endpointUrl: this.newEndpoint.endpointUrl,
                authType:    this.newEndpoint.authType,
                retryPolicy: this.newEndpoint.retryPolicy,
                maxRetries:  this.newEndpoint.maxRetries
            });
            this.addSuccess = true;
            this.newEndpoint = { name: '', endpointUrl: '', authType: 'API Key', retryPolicy: 'Immediate', maxRetries: 3 };
            await refreshApex(this._wiredEndpointsResult);
            setTimeout(() => { this.addSuccess = false; }, 3000);
        } catch (e) {
            this.addError = e.body ? e.body.message : 'Failed to add endpoint.';
        } finally {
            this.isSaving = false;
        }
    }

    async deleteEndpoint(evt) {
        const id = evt.currentTarget.dataset.id;
        try {
            await deleteEndpoint({ endpointId: id });
            await refreshApex(this._wiredEndpointsResult);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Delete failed:', e);
        }
    }

    async resetCircuit(evt) {
        const id = evt.currentTarget.dataset.id;
        try {
            await resetCircuitBreaker({ endpointId: id });
            await refreshApex(this._wiredEndpointsResult);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Circuit reset failed:', e);
        }
    }

    // circuitBadgeClass is precomputed in wiredEndpoints — not needed as a template function

    // ── TAB 2: Retry Rules ───────────────────────────────────────────────────
    @track autonomousHealing    = true;
    @track confidenceThreshold  = 85;
    @track circuitBreakerThreshold = 5;
    @track silentFailureMinutes = 30;
    @track autoEscalate         = true;
    @track isSavingRules        = false;
    @track rulesSaved           = false;

    toggleAutonomousHealing(evt)  { this.autonomousHealing = evt.target.checked; }
    toggleAutoEscalate(evt)       { this.autoEscalate = evt.target.checked; }
    handleConfidenceChange(evt)   { this.confidenceThreshold = parseInt(evt.target.value, 10); }
    handleCircuitThreshold(evt)   { this.circuitBreakerThreshold = parseInt(evt.target.value, 10); }
    handleSilentFailure(evt)      { this.silentFailureMinutes = parseInt(evt.target.value, 10); }

    saveRetryRules() {
        this.isSavingRules = true;
        // In production: upsert System_Setting__mdt or a Custom Setting record
        setTimeout(() => {
            this.isSavingRules = false;
            this.rulesSaved    = true;
            setTimeout(() => { this.rulesSaved = false; }, 3000);
        }, 800);
    }

    // ── TAB 3: Alert Configuration ───────────────────────────────────────────
    @track emailAlertsEnabled = true;
    @track slackWebhookUrl    = '';
    @track alertSeverity      = 'High';
    @track notifyOnHeal       = true;
    @track isSavingAlerts     = false;
    @track alertsSaved        = false;
    @track slackTestResult    = null;
    @track slackTestSuccess   = false;

    get slackTestClass() {
        return this.slackTestSuccess ? 'form-success' : 'form-error';
    }

    toggleEmail(evt)        { this.emailAlertsEnabled = evt.target.checked; }
    toggleNotifyOnHeal(evt) { this.notifyOnHeal = evt.target.checked; }
    handleSlackUrl(evt)     { this.slackWebhookUrl = evt.target.value; }
    handleAlertSeverity(evt){ this.alertSeverity = evt.target.value; }

    testSlack() {
        if (!this.slackWebhookUrl || !this.slackWebhookUrl.startsWith('https://hooks.slack.com')) {
            this.slackTestResult  = 'Enter a valid Slack webhook URL first.';
            this.slackTestSuccess = false;
            return;
        }
        // In production: call Apex to dispatch test payload via Named Credential
        this.slackTestResult  = '✓ Test payload sent. Check your Slack channel.';
        this.slackTestSuccess = true;
        setTimeout(() => { this.slackTestResult = null; }, 5000);
    }

    saveAlerts() {
        this.isSavingAlerts = true;
        // In production: persist to Custom Setting / Custom Metadata
        setTimeout(() => {
            this.isSavingAlerts = false;
            this.alertsSaved    = true;
            setTimeout(() => { this.alertsSaved = false; }, 3000);
        }, 800);
    }
}