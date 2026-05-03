import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getIncidentDetail from '@salesforce/apex/SentinelFlowPortalController.getIncidentDetail';

export default class SentinelFlowPortalIncidentDetail extends LightningElement {
    recordId;
    detail;
    error;

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.recordId = pageRef?.state?.c__recordId || pageRef?.state?.recordId;
    }

    @wire(getIncidentDetail, { recordId: '$recordId' })
    wiredDetail({ error, data }) {
        if (data) {
            this.detail = data;
            this.error = undefined;
        } else if (error && this.recordId) {
            this.detail = undefined;
            this.error = 'Unable to load incident detail.';
        } else {
            this.detail = undefined;
            this.error = undefined;
        }
    }

    get hasDetail() {
        return !!this.detail;
    }

    get resolvedTimeLabel() {
        return this.detail?.resolvedTime || 'Still open';
    }
}
