import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingApprovals from '@salesforce/apex/ZentomDashboardController.getPendingApprovals';
import approveWorkflow from '@salesforce/apex/ZentomDashboardController.approveWorkflow';
import rejectWorkflow from '@salesforce/apex/ZentomDashboardController.rejectWorkflow';

export default class ZentomApprovalQueue extends LightningElement {
    @track approvals = [];
    @track approvalCount = 0;
    @track isLoading = true;
    @track isRefreshing = false;

    connectedCallback() {
        this.loadApprovals();
    }

    async loadApprovals() {
        this.isRefreshing = true;
        this.isLoading = true;
        try {
            const data = await getPendingApprovals();
            this.approvalCount = data.length;
            this.approvals = data.map(w => {
                const exp = new Date(w.expiresAt);
                const rem = Math.max(0, Math.round((exp - Date.now()) / 60000));
                
                return {
                    id: w.id,
                    paddedId: w.incidentId, // using incident Name directly as we don't have integer IDs anymore
                    incidentId: w.incidentId,
                    proposedAction: w.proposedAction,
                    confidence: w.confidence,
                    confidenceClass: w.confidence >= 80 ? 'metric-value score-high' : 
                                     w.confidence >= 60 ? 'metric-value score-med' : 
                                     'metric-value score-low',
                    riskScore: w.riskScore != null ? w.riskScore.toFixed(1) : '--',
                    policyReasoning: w.policyReasoning || 'Risk exceeds autonomous threshold.',
                    ttl: rem + ' min'
                };
            });
        } catch (e) {
            this.showToast('Error', e.body ? e.body.message : e.message, 'error');
        } finally {
            this.isLoading = false;
            setTimeout(() => { this.isRefreshing = false; }, 500); // Visual feedback delay
        }
    }

    get hasApprovals() {
        return this.approvals.length > 0;
    }

    get refreshIconClass() {
        return this.isRefreshing ? 'refresh-icon spinning' : 'refresh-icon';
    }

    async handleApprove(event) {
        const wfId = event.target.dataset.id;
        // eslint-disable-next-line no-alert
        const by = prompt('Type your name to confirm approval:');
        if (!by) return;
        
        this.isLoading = true;
        try {
            const res = await approveWorkflow({ incidentId: wfId, approvedBy: by });
            const data = JSON.parse(res);
            if (data.error) {
                this.showToast('Action Failed', data.error, 'error');
            } else {
                this.showToast('Approved', `Action for ${data.incidentId} executed.`, 'success');
            }
        } catch (e) {
            this.showToast('Error', e.message, 'error');
        } finally {
            this.loadApprovals();
        }
    }

    async handleReject(event) {
        const wfId = event.target.dataset.id;
        // eslint-disable-next-line no-alert
        const reason = prompt('Reason for rejection:');
        if (!reason) return;

        this.isLoading = true;
        try {
            const res = await rejectWorkflow({ incidentId: wfId, reason: reason });
            const data = JSON.parse(res);
            if (data.error) {
                this.showToast('Action Failed', data.error, 'error');
            } else {
                this.showToast('Rejected', 'Workflow has been rejected.', 'info');
            }
        } catch (e) {
            this.showToast('Error', e.message, 'error');
        } finally {
            this.loadApprovals();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}