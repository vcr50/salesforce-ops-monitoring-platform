import { LightningElement } from 'lwc';

const COLUMNS = [
    { label: 'API', fieldName: 'apiName' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Response Time', fieldName: 'responseTime' }
];

export default class SeompPortalIntegrationTable extends LightningElement {
    columns = COLUMNS;

    rows = [
        { id: '1', apiName: 'Orders API', status: 'Failed', responseTime: '2400 ms' },
        { id: '2', apiName: 'Inventory API', status: 'Warning', responseTime: '950 ms' }
    ];
}
