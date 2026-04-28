import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getIntegrationDetail from '@salesforce/apex/SEOMPPortalController.getIntegrationDetail';

export default class SeompPortalIntegrationDetail extends LightningElement {
    recordId;
    detail;
    error;

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.recordId = pageRef?.state?.c__recordId || pageRef?.state?.recordId;
    }

    @wire(getIntegrationDetail, { recordId: '$recordId' })
    wiredDetail({ error, data }) {
        if (data) {
            this.detail = data;
            this.error = undefined;
        } else if (error && this.recordId) {
            this.detail = undefined;
            this.error = 'Unable to load integration detail.';
        } else {
            this.detail = undefined;
            this.error = undefined;
        }
    }

    get hasDetail() {
        return !!this.detail;
    }

    get responseTimeLabel() {
        return this.detail?.responseTime || 'No timing captured';
    }

    get errorMessageLabel() {
        return this.detail?.errorMessage || 'No error message captured for this log.';
    }
}
