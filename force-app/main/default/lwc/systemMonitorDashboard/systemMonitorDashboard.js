import { LightningElement, wire, track } from 'lwc';
import getSystemHealth from '@salesforce/apex/SystemMonitorController.getSystemHealth';
import getRecentLogs from '@salesforce/apex/SystemMonitorController.getRecentLogs';

const COLUMNS = [
    { label: 'Log ID', fieldName: 'Name', type: 'text' },
    { label: 'Class', fieldName: 'Class_Name__c', type: 'text' },
    { label: 'Method', fieldName: 'Method_Name__c', type: 'text' },
    { label: 'Error Type', fieldName: 'Error_Type__c', type: 'text' },
    { label: 'Retries', fieldName: 'Retry_Count__c', type: 'number' },
    { label: 'Timestamp', fieldName: 'CreatedDate', type: 'date', 
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } }
];

export default class SystemMonitorDashboard extends LightningElement {
    @track healthStatus = 'Loading...';
    @track errorCount1H = 0;
    @track failedJobs = 0;
    @track activeIncidents = 0;
    
    logs = [];
    columns = COLUMNS;

    @wire(getSystemHealth)
    wiredHealth({ error, data }) {
        if (data) {
            this.healthStatus = data.status;
            this.errorCount1H = data.errorCount1H;
            this.failedJobs = data.failedJobs;
            this.activeIncidents = data.activeIncidents;
        } else if (error) {
            this.healthStatus = 'Unknown';
            console.error('Error fetching health:', error);
        }
    }

    @wire(getRecentLogs)
    wiredLogs({ error, data }) {
        if (data && data.length > 0) {
            this.logs = data;
        } else if (error) {
            console.error('Error fetching logs:', error);
        }
    }

    get healthClass() {
        if (this.healthStatus === 'Healthy') return 'kpi-value text-green';
        if (this.healthStatus === 'Degraded') return 'kpi-value text-yellow';
        if (this.healthStatus === 'Critical') return 'kpi-value text-red';
        return 'kpi-value';
    }
}
