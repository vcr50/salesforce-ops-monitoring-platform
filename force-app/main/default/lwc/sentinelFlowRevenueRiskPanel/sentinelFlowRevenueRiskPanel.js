import { api, LightningElement, track, wire } from 'lwc';
import getOrgRiskSummary from '@salesforce/apex/RevenuePulseService.getOrgRiskSummary';
import getCurrencyConfig from '@salesforce/apex/SettingsController.getCurrencyConfig';

export default class SentinelFlowRevenueRiskPanel extends LightningElement {
    @api theme = 'light';

    @track totalRiskAmount = 0;
    @track criticalCount = 0;
    @track highCount = 0;
    @track openRisksCount = 0;
    @track topActions = [];

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

    get panelClass() {
        return `risk-panel ${this.theme === 'dark' ? 'theme-dark' : 'theme-light'}`;
    }

    get formattedRiskAmount() {
        const converted = Number(this.totalRiskAmount || 0) * this.currencyRate;
        const code = this.currencyCode;
        const locale = code === 'INR' ? 'en-IN' : 'en-US';
        return converted.toLocaleString(locale, {
            style: 'currency',
            currency: code,
            maximumFractionDigits: 0
        });
    }

    get openRisksLabel() {
        const count = this.openRisksCount || 0;
        return `${count} open ${count === 1 ? 'risk' : 'risks'}`;
    }

    get criticalLabel() {
        if (this.criticalCount > 0) {
            return `${this.criticalCount} critical revenue path${this.criticalCount === 1 ? '' : 's'}`;
        }
        return 'No critical revenue paths';
    }

    get hasActions() {
        return this.topActions.length > 0;
    }

    @wire(getOrgRiskSummary)
    wiredRiskSummary({ error, data }) {
        if (data) {
            this.totalRiskAmount = data.totalRiskAmount || 0;
            this.criticalCount = data.criticalIncidentsCount || 0;
            this.highCount = data.highIncidentsCount || 0;
            this.openRisksCount = data.openRisksCount || 0;
            this.topActions = (data.topActions || []).map((action, index) => ({
                ...action,
                key: action.riskId || action.incidentId || `risk-${index}`,
                rank: index + 1,
                businessImpact: this.cleanText(action.businessImpact),
                recommendedAction: this.cleanText(action.recommendedAction || 'Review risk')
            }));
        } else if (error) {
            this.totalRiskAmount = 0;
            this.criticalCount = 0;
            this.highCount = 0;
            this.openRisksCount = 0;
            this.topActions = [];
            console.error('Revenue Risk Panel: Failed to load risk summary', error);
        }
    }

    cleanText(value) {
        if (!value) {
            return '';
        }

        return String(value)
            .replace(/\uFFFD/g, '-')
            .replace(/[–—]/g, '-')
            .replace(/\s+/g, ' ')
            .trim();
    }
}