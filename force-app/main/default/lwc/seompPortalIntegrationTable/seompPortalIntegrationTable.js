import { LightningElement, wire } from 'lwc';
import getActiveIntegrations from '@salesforce/apex/SEOMPPortalController.getActiveIntegrations';

const COLUMNS = [
    { label: 'API', fieldName: 'apiName' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Response Time', fieldName: 'responseTime' }
];

export default class SeompPortalIntegrationTable extends LightningElement {
    columns = COLUMNS;
    rows = [];
    error;

    @wire(getActiveIntegrations)
    wiredIntegrations({ error, data }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = 'Unable to load live integration data.';
        }
    }
}
