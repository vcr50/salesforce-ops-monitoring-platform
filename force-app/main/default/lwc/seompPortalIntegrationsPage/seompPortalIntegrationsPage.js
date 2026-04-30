import { LightningElement, track, wire } from 'lwc';
import getIntegrationLogs from '@salesforce/apex/SEOMPPortalController.getIntegrationLogs';

export default class SeompPortalIntegrationsPage extends LightningElement {
    @track logs = [];
    @track integrationStats = [];

    _autoRefreshInterval;

    connectedCallback() {
        this.fetchLogs();
        // Start live stream UI automatically
        this.toggleStream();
        // Auto refresh data every 10 seconds
        this._autoRefreshInterval = setInterval(() => {
            this.fetchLogs();
        }, 10000);
    }

    disconnectedCallback() {
        clearInterval(this._autoRefreshInterval);
        if (this.isStreaming) {
            clearInterval(this._streamInterval);
        }
    }

    refreshData() {
        this.fetchLogs();
    }

    fetchLogs() {
        getIntegrationLogs()
            .then(result => {
                this.logs = result.map(log => ({
                    ...log,
                    statusClass: this.getStatusClass(log.status)
                }));
                this.calculateStats(result);
            })
            .catch(error => {
                console.error('Error fetching logs', error);
            });
    }

    getStatusClass(status) {
        if (status === 'Success') return 'status-badge healthy';
        if (status === 'Warning') return 'status-badge warning';
        if (status === 'Failed') return 'status-badge critical';
        return 'status-badge';
    }

    calculateStats(logs) {
        const statsMap = {};
        logs.forEach(log => {
            if (!statsMap[log.apiName]) {
                statsMap[log.apiName] = {
                    apiName: log.apiName,
                    totalTime: 0,
                    count: 0,
                    errorCount: 0,
                    status: 'Healthy'
                };
            }
            const time = parseInt(log.responseTime) || 0;
            statsMap[log.apiName].totalTime += time;
            statsMap[log.apiName].count += 1;
            
            if (log.status === 'Failed') {
                statsMap[log.apiName].errorCount += 1;
                statsMap[log.apiName].status = 'Failed';
            } else if (log.status === 'Warning' && statsMap[log.apiName].status !== 'Failed') {
                statsMap[log.apiName].status = 'Warning';
            }
        });

        this.integrationStats = Object.values(statsMap).map(stat => ({
            ...stat,
            avgResponseTime: Math.round(stat.totalTime / stat.count),
            statusClass: this.getStatusClass(stat.status)
        }));
    }

    // --- Terminal Logic ---
    @track terminalLogs = [];
    @track isStreaming = false;
    _streamInterval;
    _logIndex = 0;

    // Mock logs to cycle through
    _mockLogLines = [
        { type: 'INFO', msg: 'Polling payment gateway...', typeClass: 'type-info' },
        { type: 'INFO', msg: 'Received response 200 OK from Stripe.', typeClass: 'type-info' },
        { type: 'WARN', msg: 'High latency detected on ERP Sync (412ms).', typeClass: 'type-warn' },
        { type: 'INFO', msg: 'Queue length: 4 messages processing.', typeClass: 'type-info' },
        { type: 'ERR', msg: 'Timeout: Salesforce core connection dropped.', typeClass: 'type-err' },
        { type: 'INFO', msg: 'Re-establishing connection (Attempt 1/3)', typeClass: 'type-info' },
        { type: 'INFO', msg: 'Heartbeat ping successful.', typeClass: 'type-info' }
    ];

    get streamBtnLabel() {
        return this.isStreaming ? '■ Stop Stream' : '▶ Start Stream';
    }

    toggleStream() {
        if (this.isStreaming) {
            this.isStreaming = false;
            clearInterval(this._streamInterval);
        } else {
            this.isStreaming = true;
            this._streamInterval = setInterval(() => {
                this._pushLog();
            }, 800);
        }
    }

    _pushLog() {
        const mock = this._mockLogLines[this._logIndex % this._mockLogLines.length];
        this._logIndex++;
        
        const now = new Date();
        const timestamp = now.toLocaleTimeString([], { hour12: false }) + '.' + now.getMilliseconds().toString().padStart(3, '0');
        
        this.terminalLogs.push({
            id: this._logIndex,
            timestamp: timestamp,
            type: mock.type,
            typeClass: mock.typeClass,
            message: mock.msg
        });

        // Keep only last 50 logs in memory
        if (this.terminalLogs.length > 50) {
            this.terminalLogs.shift();
        }

        // Auto-scroll to bottom
        setTimeout(() => {
            const body = this.template.querySelector('.terminal-body');
            if (body) {
                body.scrollTop = body.scrollHeight;
            }
        }, 10);
    }
}