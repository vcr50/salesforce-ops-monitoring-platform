import { LightningElement, wire } from 'lwc';
import getOpenIncidents from '@salesforce/apex/SEOMPPortalController.getOpenIncidents';

const COLUMNS = [
    { label: 'Incident', fieldName: 'name' },
    { label: 'Severity', fieldName: 'severity' },
    { label: 'Status', fieldName: 'status' }
];

export default class SeompPortalIncidentTable extends LightningElement {
    columns = COLUMNS;
    rows = [];
    error;

    @wire(getOpenIncidents)
    wiredIncidents({ error, data }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = 'Unable to load live incident data.';
        }
    }
}
