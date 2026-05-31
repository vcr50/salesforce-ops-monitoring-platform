import { api, LightningElement, wire, track } from 'lwc';
import getSummary from '@salesforce/apex/SentinelFlowPortalController.getSummary';
import getOpenIncidents from '@salesforce/apex/SentinelFlowPortalController.getOpenIncidents';
import getSystemHealth from '@salesforce/apex/SystemMonitorController.getSystemHealth';
import healIncident from '@salesforce/apex/SentinelFlowPortalController.healIncident';
import getCurrencyConfig from '@salesforce/apex/SettingsController.getCurrencyConfig';

const CONFIDENCE_THRESHOLD = 85;

export default class SentinelFlowGuardianHome extends LightningElement {
    @api theme = 'light';

    @track healthStatus = '--';
    @track errorCount1H = 0;
    @track failedJobs = 0;
    @track activeIncidents = 0;
    @track revenueAtRisk = '0';
    @track rawRevenueAtRisk = 0;
    @track currencyCode = 'USD';
    @track currencySymbol = '$';
    @track currencyRate = 1.0;
    @track usersAffected = 0;
    @track openIncidents = 0;
    @track autoHealedToday = 0;
    @track recommendations = [];
    @track showHealResult = false;
    @track healResultSuccess = false;
    @track healResultMessage = '';
    @track healResultIcon = 'utility:success';
    @track chartSamples = [42, 48, 45, 58, 62, 56, 68, 71, 65, 74, 79, 72, 82, 76];

    _chartTimer;
    _chartTick = 0;

    connectedCallback() {
        this.loadCurrency();
        this._chartTimer = setInterval(() => {
            this.updateChartSample();
        }, 2500);
    }

    disconnectedCallback() {
        if (this._chartTimer) {
            clearInterval(this._chartTimer);
        }
    }

    get hasRecommendations() {
        return this.recommendations && this.recommendations.length > 0;
    }

    get homeClass() {
        return `guardian-home ${this.theme === 'dark' ? 'theme-dark' : 'theme-light'}`;
    }

    get chartPoints() {
        const width = 640;
        const height = 180;
        const max = 100;
        const step = width / (this.chartSamples.length - 1);
        return this.chartSamples
            .map((value, index) => `${Math.round(index * step)},${Math.round(height - (value / max * height))}`)
            .join(' ');
    }

    get chartAreaPoints() {
        return `0,180 ${this.chartPoints} 640,180`;
    }

    get chartBars() {
        return this.chartSamples.map((value, index) => ({
            id: `bar-${index}`,
            style: `height: ${Math.max(value, 12)}%;`
        }));
    }

    get chartLatest() {
        return this.chartSamples[this.chartSamples.length - 1];
    }

    get chartDelta() {
        const previous = this.chartSamples[this.chartSamples.length - 2] || 0;
        const delta = this.chartLatest - previous;
        return `${delta >= 0 ? '+' : ''}${delta}%`;
    }

    get chartLatency() {
        return `${Math.max(86, 128 - this.chartLatest)}ms`;
    }

    get chartEvents() {
        return this.chartLatest + this.errorCount1H + this.failedJobs;
    }

    get formattedRevenueAtRisk() {
        const converted = Number(this.rawRevenueAtRisk || 0) * Number(this.currencyRate || 1);
        const locale = this.currencyCode === 'INR' ? 'en-IN' : 'en-US';
        return converted.toLocaleString(locale, {
            style: 'currency',
            currency: this.currencyCode || 'USD',
            maximumFractionDigits: 0
        });
    }

    loadCurrency() {
        getCurrencyConfig()
            .then(config => {
                if (config) {
                    this.currencyCode = config.code || 'USD';
                    this.currencySymbol = config.symbol || '$';
                    this.currencyRate = config.rate || 1.0;
                }
            })
            .catch(error => {
                console.error('Guardian Home: Failed to load currency config', error);
            });
    }

    updateChartSample() {
        this._chartTick += 1;
        const nextValue = Math.round(
            62
            + Math.sin(this._chartTick / 1.6) * 18
            + Math.cos(this._chartTick / 3.1) * 9
            + Math.min(this.errorCount1H, 12)
        );
        const bounded = Math.max(18, Math.min(96, nextValue));
        this.chartSamples = [...this.chartSamples.slice(1), bounded];
    }

    @wire(getSystemHealth)
    wiredHealth({ error, data }) {
        if (data) {
            this.healthStatus = data.status;
            this.errorCount1H = data.errorCount1H;
            this.failedJobs = data.failedJobs;
            this.activeIncidents = data.activeIncidents;
        } else if (error) {
            this.healthStatus = 'Unknown';
            console.error('Guardian Home: Failed to load system health', error);
        }
    }

    @wire(getSummary)
    wiredSummary({ error, data }) {
        if (data) {
            this.rawRevenueAtRisk = data.totalRevenueAtRisk || 0;
            this.revenueAtRisk = data.totalRevenueAtRisk
                ? Number(data.totalRevenueAtRisk).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })
                : '0';
            this.usersAffected = data.totalUsersAffected || 0;
            this.openIncidents = data.openIncidents || 0;
            this.autoHealedToday = data.autoHealedToday || 0;
        } else if (error) {
            console.error('Guardian Home: Failed to load summary', error);
        }
    }

    @wire(getOpenIncidents)
    wiredIncidents({ error, data }) {
        if (data) {
            this.recommendations = data
                .filter(inc => inc.rootCause || inc.recommendedAction)
                .map(inc => {
                    const confidence = inc.aiConfidence || 0;
                    return {
                        incidentId: inc.id,
                        name: inc.name,
                        severity: inc.severity,
                        rootCause: inc.rootCause || 'Under investigation',
                        recommendedAction: inc.recommendedAction || 'Escalate',
                        confidence: confidence,
                        canAutoHeal: confidence >= CONFIDENCE_THRESHOLD && !inc.selfHealAttempted,
                        isHealing: false,
                        confidenceStyle: `width: ${confidence}%;`
                    };
                });
        } else if (error) {
            console.error('Guardian Home: Failed to load incidents', error);
        }
    }

    handleHealClick(event) {
        const incidentId = event.currentTarget.dataset.incidentId;
        const action = event.currentTarget.dataset.action;

        const rec = this.recommendations.find(r => r.incidentId === incidentId);
        if (rec) {
            rec.isHealing = true;
        }

        healIncident({ incidentId: incidentId })
            .then(result => {
                this.showHealResult = true;
                this.healResultSuccess = result.success;
                this.healResultMessage = result.message;
                this.healResultIcon = result.success ? 'utility:success' : 'utility:error';

                if (rec) {
                    rec.isHealing = false;
                    if (result.success) {
                        rec.canAutoHeal = false;
                    }
                }

                setTimeout(() => {
                    this.showHealResult = false;
                }, 5000);
            })
            .catch(error => {
                this.showHealResult = true;
                this.healResultSuccess = false;
                this.healResultMessage = error.body?.message || 'Heal action failed';
                this.healResultIcon = 'utility:error';

                if (rec) {
                    rec.isHealing = false;
                }

                setTimeout(() => {
                    this.showHealResult = false;
                }, 5000);
            });
    }

    closeToast() {
        this.showHealResult = false;
    }
}