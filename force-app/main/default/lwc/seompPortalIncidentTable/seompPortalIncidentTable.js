import { LightningElement } from 'lwc';

const COLUMNS = [
    { label: 'Incident', fieldName: 'name' },
    { label: 'Severity', fieldName: 'severity' },
    { label: 'Status', fieldName: 'status' }
];

export default class SeompPortalIncidentTable extends LightningElement {
    columns = COLUMNS;

    rows = [
        { id: '1', name: 'INC-0000', severity: 'Critical', status: 'New' },
        { id: '2', name: 'INC-0001', severity: 'High', status: 'New' }
    ];
}
