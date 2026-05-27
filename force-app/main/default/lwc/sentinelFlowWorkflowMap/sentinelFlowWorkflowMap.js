import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import buildWorkflowChain from '@salesforce/apex/RevenueWorkflowMapper.buildWorkflowChain';
import syncToERP from '@salesforce/apex/NetSuiteConnector.syncToERP';
import { refreshApex } from '@salesforce/apex';

export default class SentinelFlowWorkflowMap extends LightningElement {
    @track workflowData;
    @track isLoading = true;
    @track isSyncing = false;
    @track error;
    _wiredResult;

    @wire(buildWorkflowChain)
    wiredWorkflow(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.workflowData = {
                ...data,
                nodes: data.nodes.map(n => ({
                    ...n,
                    statusClass: `node-box status-${n.status}`
                })),
                links: data.links.map(l => ({
                    ...l,
                    linkClass: `workflow-link link-${l.status}`
                }))
            };
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.workflowData = undefined;
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

    get hasBrokenLinks() {
        return this.workflowData?.brokenLinks > 0;
    }

    handleSimulateERP() {
        this.isSyncing = true;
        syncToERP({ opportunityId: null })
            .then(result => {
                if (result.isSuccess) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'ERP Sync Completed Successfully',
                            variant: 'success'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Sync Failed',
                            message: result.errorMessage,
                            variant: 'error',
                            mode: 'sticky'
                        })
                    );
                }
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isSyncing = false;
            });
    }
}