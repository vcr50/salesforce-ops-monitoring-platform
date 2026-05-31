import { LightningElement, wire, track } from 'lwc';
import getExecutiveMetrics from '@salesforce/apex/ExecutiveIntelligenceController.getExecutiveMetrics';
import getCurrencyConfig from '@salesforce/apex/SettingsController.getCurrencyConfig';

export default class SentinelFlowExecutiveDashboard extends LightningElement {
    @track metrics;
    @track error;
    isLoading = true;

    @track currencyCode = 'USD';
    @track currencySymbol = '$';
    @track currencyRate = 1.0;

    connectedCallback() {
        this._loadCurrency();
    }

    _loadCurrency() {
        getCurrencyConfig()
            .then(config => {
                if (config) {
                    this.currencyCode = config.code || 'USD';
                    this.currencySymbol = config.symbol || '$';
                    this.currencyRate = config.rate || 1.0;
                }
            })
            .catch(err => {
                console.error('Error loading currency config:', err);
            });
    }

    @wire(getExecutiveMetrics)
    wiredMetrics({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.metrics = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.metrics = undefined;
        }
    }

    get formattedRevenueAtRisk() {
        if (!this.metrics || this.metrics.totalRevenueAtRisk == null) return `${this.currencySymbol}0`;
        const converted = this.metrics.totalRevenueAtRisk * this.currencyRate;
        const code = this.currencyCode;
        const locale = code === 'INR' ? 'en-IN' : 'en-US';
        return new Intl.NumberFormat(locale, { style: 'currency', currency: code, maximumFractionDigits: 0 }).format(converted);
    }

    get formattedRevenueSaved() {
        if (!this.metrics || this.metrics.revenueSavedByAI == null) return `${this.currencySymbol}0`;
        const converted = this.metrics.revenueSavedByAI * this.currencyRate;
        const code = this.currencyCode;
        const locale = code === 'INR' ? 'en-IN' : 'en-US';
        return new Intl.NumberFormat(locale, { style: 'currency', currency: code, maximumFractionDigits: 0 }).format(converted);
    }

    get safetyScoreClass() {
        if (!this.metrics) return 'score-circle neutral';
        if (this.metrics.businessSafetyScore >= 90) return 'score-circle excellent';
        if (this.metrics.businessSafetyScore >= 75) return 'score-circle warning';
        return 'score-circle danger';
    }
}