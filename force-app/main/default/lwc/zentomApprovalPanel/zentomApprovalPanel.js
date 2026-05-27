import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getIncident from '@salesforce/apex/ZentomApprovalController.getIncident';
import approveIncident from '@salesforce/apex/ZentomApprovalController.approveIncident';
import rejectIncident from '@salesforce/apex/ZentomApprovalController.rejectIncident';
import executeApprovedAction from '@salesforce/apex/ZentomExecutionController.executeApprovedAction';

export default class ZentomApprovalPanel extends LightningElement {
    @api recordId;

    incident;
    wiredIncident;
    errorMessage;
    isSaving = false;
    showRejectReason = false;
    rejectionReason = '';

    @wire(getIncident, { incidentId: '$recordId' })
    wiredGetIncident(result) {
        this.wiredIncident = result;
        if (result.data) {
            this.incident = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.incident = undefined;
            this.errorMessage = this.reduceError(result.error);
        }
    }

    get actionsDisabled() {
        return this.isSaving || !this.incident?.canApprove;
    }

    get rejectDisabled() {
        return this.isSaving || !this.incident?.canReject;
    }

    get rejectLabel() {
        return this.showRejectReason ? 'Confirm Reject' : 'Reject';
    }

    get showExecuteAction() {
        return this.incident?.canExecute;
    }

    handleReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    async handleApprove() {
        this.isSaving = true;
        try {
            this.incident = await approveIncident({ incidentId: this.recordId });
            this.showToast('Approved', 'Human approval was captured.', 'success');
            await refreshApex(this.wiredIncident);
        } catch (error) {
            this.showToast('Approval failed', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleReject() {
        if (!this.showRejectReason) {
            this.showRejectReason = true;
            return;
        }

        this.isSaving = true;
        try {
            this.incident = await rejectIncident({
                incidentId: this.recordId,
                reason: this.rejectionReason
            });
            this.showToast('Rejected', 'Human rejection was captured.', 'success');
            await refreshApex(this.wiredIncident);
        } catch (error) {
            this.showToast('Rejection failed', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleExecute() {
        this.isSaving = true;
        try {
            const result = await executeApprovedAction({ incidentId: this.recordId });
            this.showToast('Action created', result.message, 'success');
            await refreshApex(this.wiredIncident);
        } catch (error) {
            this.showToast('Execution failed', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}