import { LightningElement, wire } from 'lwc';
import getSummary from '@salesforce/apex/SEOMPPortalController.getSummary';

export default class SeompPortalSummary extends LightningElement {
    criticalIncidents = 0;
    openIncidents = 0;
    failedIntegrations = 0;
    warningIntegrations = 0;
    error;
    lastRefreshedLabel = 'Waiting for data';

    @wire(getSummary)
    wiredSummary({ error, data }) {
        if (data) {
            this.criticalIncidents = data.criticalIncidents;
            this.openIncidents = data.openIncidents;
            this.failedIntegrations = data.failedIntegrations;
            this.warningIntegrations = data.warningIntegrations;
            this.error = undefined;
            this.lastRefreshedLabel = new Date().toLocaleString();
        } else if (error) {
            this.error = 'Unable to load live summary data.';
        }
    }
}
