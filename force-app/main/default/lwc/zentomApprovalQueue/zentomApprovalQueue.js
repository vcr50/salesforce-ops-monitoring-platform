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
            // Mocking data to match dashboard
            const mockWorkflows = [];
            for (let i = 0; i < 9; i++) {
                const idNum = 231 - i;
                mockWorkflows.push({
                    workflowId: idNum,
                    incidentId: `INC-2025-${String(idNum + 100).padStart(4, '0')}`,
                    proposedAction: i % 2 === 0 ? `Restart Service ${i}` : `Scale Component ${i}`,
                    confidence: 85 - i * 5,
                    riskScore: 8.5 + (i % 3) * 0.5,
                    policyReasoning: 'Risk exceeds autonomous threshold.',
                    expiresAt: Date.now() + 600000 * (i + 1)
                });
            }

            this.approvalCount = mockWorkflows.length;
            this.approvals = mockWorkflows.map(w => {
                const exp = new Date(w.expiresAt);
                const rem = Math.max(0, Math.round((exp - Date.now()) / 60000));
                
                return {
                    workflowId: w.workflowId,
                    paddedId: String(w.workflowId).padStart(7, '0'),
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
            this.showToast('Error', e.message, 'error');
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
            const res = await approveWorkflow({ workflowId: parseInt(wfId, 10), approvedBy: by });
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
            const res = await rejectWorkflow({ workflowId: parseInt(wfId, 10), reason: reason });
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