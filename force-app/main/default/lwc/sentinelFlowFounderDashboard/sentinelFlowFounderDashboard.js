import { LightningElement, track, wire } from 'lwc';
import calculateSafety from '@salesforce/apex/BusinessSafetyScore.calculate';
import { refreshApex } from '@salesforce/apex';

export default class SentinelFlowFounderDashboard extends LightningElement {
    @track safetyData;
    @track isLoading = true;
    @track error;
    _wiredResult;

    @wire(calculateSafety)
    wiredSafety(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.safetyData = {
                ...data,
                isGradeA: data.grade === 'A',
                isGradeB: data.grade === 'B',
                isGradeC: data.grade === 'C',
                isGradeF: data.grade === 'D' || data.grade === 'F'
            };
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.safetyData = undefined;
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }
}