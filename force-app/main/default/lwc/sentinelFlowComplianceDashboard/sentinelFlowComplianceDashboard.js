import { LightningElement, track, wire } from 'lwc';
import evaluateSecurity from '@salesforce/apex/SecurityScoreEngine.evaluate';
import { refreshApex } from '@salesforce/apex';

export default class SentinelFlowComplianceDashboard extends LightningElement {
    @track scoreData;
    @track isLoading = true;
    @track error;
    _wiredResult;

    @wire(evaluateSecurity)
    wiredSecurity(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.scoreData = {
                ...data,
                isGradeA: data.grade === 'A',
                isGradeB: data.grade === 'B',
                isGradeC: data.grade === 'C',
                isGradeF: data.grade === 'D' || data.grade === 'F',
                categories: data.categories.map(c => ({
                    ...c,
                    progressClass: c.status === 'Healthy' ? 'progress-healthy' : (c.status === 'Warning' ? 'progress-warning' : 'progress-critical'),
                    progressPercent: c.score,
                    widthStyle: `width: ${c.score}%`
                }))
            };
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.scoreData = undefined;
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    get findingCount() {
        return this.scoreData?.findings?.length || 0;
    }
}