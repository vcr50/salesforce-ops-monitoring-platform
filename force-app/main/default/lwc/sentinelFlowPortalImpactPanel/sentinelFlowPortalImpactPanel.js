import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe } from 'lightning/empApi';
import calculateAllOpen from '@salesforce/apex/BusinessImpactCalculator.calculateAllOpen';

export default class SentinelFlowPortalImpactPanel extends LightningElement {
    @track impactData = [];
    error;
    isCalculating = false;

    _wiredResult;
    _subscription;

    @wire(calculateAllOpen)
    wiredImpact(result) {
        this._wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.impactData = data.map(item => ({
                ...item,
                revenueFormatted: this._fmtMoney(item.revenueAtRisk),
                usersFormatted: item.usersAffected.toLocaleString(),
                riskClass: this._riskClass(item.riskLevel)
            }));
            this.error = undefined;
        } else if (error) {
            this.impactData = [];
            this.error = 'Unable to load impact data.';
        }
    }

    connectedCallback() {
        subscribe('/event/Integration_Health_Event__e', -1, () => {
            this.handleRefresh();
        }).then(sub => { this._subscription = sub; })
          .catch(err => { console.warn('empApi subscribe failed:', err); });
    }

    disconnectedCallback() {
        if (this._subscription) unsubscribe(this._subscription, () => {});
    }

    get hasData() { return this.impactData.length > 0; }
    
    get totalRevenueRisk() {
        const total = this.impactData.reduce((sum, item) => sum + (item.revenueAtRisk || 0), 0);
        return this._fmtMoney(total);
    }
    
    get totalUsersAffected() {
        const total = this.impactData.reduce((sum, item) => sum + (item.usersAffected || 0), 0);
        return total.toLocaleString();
    }
    
    get activeImpactEvents() {
        return this.impactData.length;
    }

    handleRefresh() {
        this.isCalculating = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isCalculating = false;
        });
    }

    _fmtMoney(n) {
        if (n >= 1000000) return '$' + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000)    return '$' + (n / 1000).toFixed(0) + 'K';
        return '$' + n.toFixed(0);
    }

    _riskClass(r) {
        return { Critical: 'risk-critical', High: 'risk-high', Medium: 'risk-medium', Low: 'risk-low' }[r] || 'risk-low';
    }

    get chartBars() {
        if (!this.impactData || this.impactData.length === 0) return [];
        
        let sums = { Critical: 0, High: 0, Medium: 0, Low: 0 };
        let total = 0;
        
        this.impactData.forEach(item => {
            const risk = item.riskLevel || 'Low';
            const rev = item.revenueAtRisk || 0;
            if (sums[risk] !== undefined) sums[risk] += rev;
            total += rev;
        });
        
        if (total === 0) return [];
        
        return [
            { label: 'Critical', value: sums.Critical, pct: Math.round((sums.Critical / total) * 100), cssClass: 'chart-bar bar-critical', fmt: this._fmtMoney(sums.Critical), legendClass: 'legend-dot bar-critical' },
            { label: 'High', value: sums.High, pct: Math.round((sums.High / total) * 100), cssClass: 'chart-bar bar-high', fmt: this._fmtMoney(sums.High), legendClass: 'legend-dot bar-high' },
            { label: 'Medium', value: sums.Medium, pct: Math.round((sums.Medium / total) * 100), cssClass: 'chart-bar bar-medium', fmt: this._fmtMoney(sums.Medium), legendClass: 'legend-dot bar-medium' },
            { label: 'Low', value: sums.Low, pct: Math.round((sums.Low / total) * 100), cssClass: 'chart-bar bar-low', fmt: this._fmtMoney(sums.Low), legendClass: 'legend-dot bar-low' }
        ].filter(bar => bar.value > 0).map(bar => ({ ...bar, styleStr: 'width: ' + bar.pct + '%;' }));
    }
}
