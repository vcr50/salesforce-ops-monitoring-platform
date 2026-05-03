import { LightningElement } from 'lwc';

export default class SentinelFlowPortalCommandCenter extends LightningElement {
    _autoRefreshInterval;

    connectedCallback() {
        this._autoRefreshInterval = setInterval(() => {
            this.refreshAll();
        }, 10000);
    }

    disconnectedCallback() {
        clearInterval(this._autoRefreshInterval);
    }

    refreshAll() {
        // Find and refresh the summary panel
        const summary = this.template.querySelector('c-sentinel-flow-portal-summary');
        if (summary && typeof summary.refreshData === 'function') {
            summary.refreshData();
        }
        // Find and refresh the incident table
        const incidentTable = this.template.querySelector('c-sentinel-flow-portal-incident-table');
        if (incidentTable && typeof incidentTable.refreshData === 'function') {
            incidentTable.refreshData();
        }
    }

    runAIAnalysis() {
        // Trigger the child copilot component to run an analysis
        const copilot = this.template.querySelector('c-sentinel-flow-portal-copilot');
        if (copilot) {
            copilot.currentInput = 'analyze latest incident';
            copilot.sendMessage();
        }
    }
}