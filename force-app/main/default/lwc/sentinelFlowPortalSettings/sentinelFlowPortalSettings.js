import { LightningElement, track, wire } from 'lwc';
import getEndpoints        from '@salesforce/apex/IntegrationEndpointController.getEndpoints';
import createEndpoint      from '@salesforce/apex/IntegrationEndpointController.createEndpoint';
import deleteEndpoint      from '@salesforce/apex/IntegrationEndpointController.deleteEndpoint';
import resetCircuitBreaker from '@salesforce/apex/IntegrationEndpointController.resetCircuitBreaker';
import loadSettings        from '@salesforce/apex/SettingsController.loadSettings';
import saveRetryRules      from '@salesforce/apex/SettingsController.saveRetryRules';
import saveAlertConfig     from '@salesforce/apex/SettingsController.saveAlertConfig';
import testSlackWebhook    from '@salesforce/apex/SettingsController.testSlackWebhook';
import scheduleDefault     from '@salesforce/apex/RevenuePulseSchedulable.scheduleDefault';
import getJobStatus        from '@salesforce/apex/RevenuePulseSchedulable.getJobStatus';
import getCurrentSubscription from '@salesforce/apex/SubscriptionService.getCurrentSubscription';
import { refreshApex } from '@salesforce/apex';

export default class SentinelFlowPortalSettings extends LightningElement {

    // ── Tab state ────────────────────────────────────────────────────────────
    @track activeTab = 'integrations';
    @track subscription;
    @track subscriptionError;

    get isTab1() { return this.activeTab === 'integrations'; }
    get isTab2() { return this.activeTab === 'retry'; }
    get isTab3() { return this.activeTab === 'alerts'; }
    get isTab4() { return this.activeTab === 'automation'; }

    get tab1Class() { return 'tab-btn' + (this.isTab1 ? ' tab-active' : ''); }
    get tab2Class() { return 'tab-btn' + (this.isTab2 ? ' tab-active' : ''); }
    get tab3Class() { return 'tab-btn' + (this.isTab3 ? ' tab-active' : ''); }
    get tab4Class() { return 'tab-btn' + (this.isTab4 ? ' tab-active' : ''); }

    switchTab(evt) {
        this.activeTab = evt.currentTarget.dataset.tab;
    }

    // ── TAB 1: Integration Endpoints ─────────────────────────────────────────
    @track endpoints = [];
    @track loadingEndpoints = true;
    @track isSaving = false;
    @track addError = null;
    @track endpointLoadError = null;
    @track addSuccess = false;
    @track formKey = 0;

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
            this.endpointLoadError = null;
        } else if (result.error) {
            this.loadingEndpoints = false;
            this.endpoints = [];
            this.endpointLoadError = result.error?.body?.message || 'Unable to load monitored endpoints.';
        }
    }

    get hasEndpoints() { return this.endpoints && this.endpoints.length > 0; }
    get endpointCount() { return this.endpoints ? this.endpoints.length : 0; }

    handleEndpointField(evt) {
        const field = evt.currentTarget.dataset.field;
        const val   = evt.currentTarget.value;
        this.newEndpoint = { ...this.newEndpoint, [field]: field === 'maxRetries' ? parseInt(val, 10) : val };
        // Clear validation error as soon as user starts correcting the form
        if (this.addError) {
            this.addError = null;
        }
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
            // Reset form state
            this.newEndpoint = { name: '', endpointUrl: '', authType: 'API Key', retryPolicy: 'Immediate', maxRetries: 3 };
            // Increment key to force LWC to destroy and re-create the form DOM,
            // which is the only reliable way to visually clear standard <input> / <select> elements
            this.formKey += 1;
            await refreshApex(this._wiredEndpointsResult);
            this.endpointLoadError = null;
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

    // ── TAB 2: Retry Rules ───────────────────────────────────────────────────
    @track autonomousHealing       = true;
    @track confidenceThreshold     = 85;
    @track circuitBreakerThreshold = 5;
    @track silentFailureMinutes    = 30;
    @track autoEscalate            = true;
    @track isSavingRules           = false;
    @track rulesSaved              = false;
    @track rulesSaveError          = null;

    // ── TAB 3: Alert Configuration ───────────────────────────────────────────
    @track emailAlertsEnabled = true;
    @track slackWebhookPath   = '';
    @track alertSeverity      = 'High';
    @track notifyOnHeal       = true;
    @track isSavingAlerts     = false;
    @track alertsSaved        = false;
    @track alertsSaveError    = null;
    @track slackTestResult    = null;
    @track slackTestSuccess   = false;
    @track isTestingSlack     = false;

    // ── Load all settings on connect ─────────────────────────────────────────
    connectedCallback() {
        this._loadSettingsFromApex();
        this._loadSubscription();
    }

    async _loadSubscription() {
        this.subscriptionError = null;
        try {
            this.subscription = await getCurrentSubscription();
        } catch (e) {
            this.subscription = null;
            this.subscriptionError = e?.body?.message || 'Unable to load subscription.';
        }
    }

    async _loadSettingsFromApex() {
        try {
            const s = await loadSettings();
            if (s) {
                this.autonomousHealing       = s.autonomousHealing    ?? true;
                this.confidenceThreshold     = s.confidenceThreshold  ?? 85;
                this.circuitBreakerThreshold = s.circuitBreakerThreshold ?? 5;
                this.silentFailureMinutes    = s.silentFailureMinutes  ?? 30;
                this.autoEscalate            = s.autoEscalate          ?? true;
                this.emailAlertsEnabled      = s.emailAlertsEnabled    ?? true;
                this.slackWebhookPath        = s.slackWebhookPath      ?? '';
                this.alertSeverity           = s.alertSeverity         ?? 'High';
                this.notifyOnHeal            = s.notifyOnHeal          ?? true;
            }
        } catch (e) {
            // Non-fatal: defaults already set above
            // eslint-disable-next-line no-console
            console.warn('Could not load settings from Apex:', e);
        }
    }

    // ── Tab 2 handlers ───────────────────────────────────────────────────────
    toggleAutonomousHealing(evt)  { this.autonomousHealing = evt.target.checked; }
    toggleAutoEscalate(evt)       { this.autoEscalate = evt.target.checked; }
    handleConfidenceChange(evt)   { this.confidenceThreshold = parseInt(evt.target.value, 10); }
    handleCircuitThreshold(evt)   { this.circuitBreakerThreshold = parseInt(evt.target.value, 10); }
    handleSilentFailure(evt)      { this.silentFailureMinutes = parseInt(evt.target.value, 10); }

    async saveRetryRulesHandler() {
        this.isSavingRules = true;
        this.rulesSaved    = false;
        this.rulesSaveError = null;
        try {
            await saveRetryRules({
                autonomousHealing:       this.autonomousHealing,
                confidenceThreshold:     this.confidenceThreshold,
                circuitBreakerThreshold: this.circuitBreakerThreshold,
                silentFailureMinutes:    this.silentFailureMinutes,
                autoEscalate:            this.autoEscalate
            });
            this.rulesSaved = true;
            setTimeout(() => { this.rulesSaved = false; }, 3000);
        } catch (e) {
            this.rulesSaveError = e.body ? e.body.message : 'Failed to save retry rules.';
        } finally {
            this.isSavingRules = false;
        }
    }

    // ── Tab 3 handlers ───────────────────────────────────────────────────────
    toggleEmail(evt)         { this.emailAlertsEnabled = evt.target.checked; }
    toggleNotifyOnHeal(evt)  { this.notifyOnHeal = evt.target.checked; }
    handleSlackPath(evt)     { this.slackWebhookPath = evt.target.value; }
    handleAlertSeverity(evt) { this.alertSeverity = evt.target.value; }

    async testSlack() {
        if (!this.slackWebhookPath || !this.slackWebhookPath.startsWith('/services/')) {
            this.slackTestResult  = 'Enter a valid Slack webhook path — e.g. /services/T.../B.../...';
            this.slackTestSuccess = false;
            return;
        }
        this.isTestingSlack   = true;
        this.slackTestResult  = null;
        try {
            const result = await testSlackWebhook({ webhookPath: this.slackWebhookPath });
            this.slackTestSuccess = result === 'SUCCESS';
            this.slackTestResult  = this.slackTestSuccess
                ? '✓ Test payload sent. Check your Slack channel.'
                : result;
        } catch (e) {
            this.slackTestSuccess = false;
            this.slackTestResult  = e.body ? e.body.message : 'Test failed.';
        } finally {
            this.isTestingSlack = false;
            setTimeout(() => { this.slackTestResult = null; }, 6000);
        }
    }

    async saveAlertsHandler() {
        this.isSavingAlerts = true;
        this.alertsSaved    = false;
        this.alertsSaveError = null;
        try {
            await saveAlertConfig({
                emailAlertsEnabled: this.emailAlertsEnabled,
                slackWebhookPath:   this.slackWebhookPath,
                alertSeverity:      this.alertSeverity,
                notifyOnHeal:       this.notifyOnHeal
            });
            this.alertsSaved = true;
            setTimeout(() => { this.alertsSaved = false; }, 3000);
        } catch (e) {
            this.alertsSaveError = e.body ? e.body.message : 'Failed to save alert config.';
        } finally {
            this.isSavingAlerts = false;
        }
    }

    get slackTestClass() {
        return this.slackTestSuccess ? 'form-success' : 'form-error';
    }

    get subscriptionPlan() {
        return this.subscription?.plan || 'Loading';
    }

    get subscriptionStatus() {
        return this.subscription?.status || (this.subscriptionError ? 'Unavailable' : 'Checking');
    }

    get subscriptionExpiryLabel() {
        if (this.subscription?.expiryDate) {
            return this.subscription.expiryDate;
        }
        return 'Not set';
    }

    get subscriptionIncidentUsage() {
        if (!this.subscription) {
            return 'Loading';
        }
        if (this.subscription.professional || this.subscription.enterprise) {
            return `${this.subscription.currentIncidentCount} / Unlimited`;
        }
        return `${this.subscription.currentIncidentCount} / ${this.subscription.starterIncidentLimit}`;
    }

    get subscriptionBadgeClass() {
        if (this.subscription?.enterprise) {
            return 'badge badge-enterprise';
        }
        if (this.subscription?.professional) {
            return 'badge badge-pro';
        }
        return this.subscription?.active ? 'badge badge-circuit-half' : 'badge badge-circuit-open';
    }

    // ── TAB 4: Automation — Revenue Pulse Scheduler ───────────────────────────
    @track pulseJobData      = {};
    @track isScheduling      = false;
    @track pulseScheduleError   = null;
    @track pulseScheduleSuccess = false;
    _wiredJobStatus;

    @wire(getJobStatus)
    wiredJobStatus(result) {
        this._wiredJobStatus = result;
        if (result.data) {
            this.pulseJobData = result.data;
        }
    }

    get pulseStatusLabel() {
        return this.pulseJobData.isScheduled ? 'ACTIVE' : 'NOT SCHEDULED';
    }

    get pulseStatusBadgeClass() {
        return this.pulseJobData.isScheduled
            ? 'badge badge-circuit-closed'
            : 'badge badge-circuit-open';
    }

    get pulseJobState() {
        return this.pulseJobData.state || 'NOT_SCHEDULED';
    }

    get nextFireDisplay() {
        if (!this.pulseJobData.nextFireTime) return '—';
        return new Date(this.pulseJobData.nextFireTime).toLocaleString('en-IN', {
            dateStyle: 'medium', timeStyle: 'short'
        });
    }

    get prevFireDisplay() {
        if (!this.pulseJobData.previousFireTime) return 'Never';
        return new Date(this.pulseJobData.previousFireTime).toLocaleString('en-IN', {
            dateStyle: 'medium', timeStyle: 'short'
        });
    }

    async scheduleRevenuePulse() {
        this.isScheduling      = true;
        this.pulseScheduleError   = null;
        this.pulseScheduleSuccess = false;
        try {
            await scheduleDefault();
            this.pulseScheduleSuccess = true;
            await refreshApex(this._wiredJobStatus);
            setTimeout(() => { this.pulseScheduleSuccess = false; }, 4000);
        } catch (e) {
            this.pulseScheduleError = e.body ? e.body.message : 'Failed to schedule Revenue Pulse.';
        } finally {
            this.isScheduling = false;
        }
    }

    async refreshPulseStatus() {
        await refreshApex(this._wiredJobStatus);
    }
}