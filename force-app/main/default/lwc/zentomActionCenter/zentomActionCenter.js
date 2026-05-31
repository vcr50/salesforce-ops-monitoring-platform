import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingActions from '@salesforce/apex/ZentomDashboardController.getPendingActions';
import executeApprovedAction from '@salesforce/apex/ZentomDashboardController.executeApprovedAction';

export default class ZentomActionCenter extends LightningElement {
    @track actions = [];
    @track actionCount = 0;
    
    isLoading = false;
    isRefreshing = false;

    connectedCallback() {
        this.loadActions();
    }

    async loadActions() {
        this.isRefreshing = true;
        this.isLoading = true;
        try {
            const data = await getPendingActions();
            this.actionCount = data.length;
            this.actions = data.map(a => {
                return {
                    id: a.id,
                    paddedId: a.incidentId,
                    incidentId: a.incidentId,
                    incidentType: a.incidentType,
                    action: a.action,
                    runbook: a.runbook || 'N/A',
                    confidence: a.confidence,
                    confidenceClass: a.confidence >= 80 ? 'metric-value score-high' : 
                                     a.confidence >= 60 ? 'metric-value score-med' : 
                                     'metric-value score-low',
                    riskScore: a.riskScore != null ? a.riskScore.toFixed(1) : '--',
                    approvedBy: a.approvedBy
                };
            });
        } catch (e) {
            this.showToast('Error', e.body ? e.body.message : e.message, 'error');
        } finally {
            this.isLoading = false;
            setTimeout(() => { this.isRefreshing = false; }, 500);
        }
    }

    handleRefresh() {
        this.loadActions();
    }

    get hasActions() {
        return this.actions && this.actions.length > 0;
    }

    async handleExecute(event) {
        const incId = event.target.dataset.id;
        // eslint-disable-next-line no-alert
        const executor = prompt('Type your name to confirm execution:');
        if (!executor) return;
        
        this.isLoading = true;
        try {
            const res = await executeApprovedAction({ incidentId: incId, executedBy: executor });
            const data = JSON.parse(res);
            if (data.error) {
                this.showToast('Execution Failed', data.error, 'error');
            } else {
                this.showToast('Action Executed', `Successfully executed. Case ${data.caseNumber} created.`, 'success');
                this.loadActions();
            }
        } catch (e) {
            this.showToast('Error executing action', e.body ? e.body.message : e.message, 'error');
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
