import { LightningElement, api, wire, track } from 'lwc';
import getRetryLogsForIncident from '@salesforce/apex/RetryLogService.getRetryLogsForIncident';
import getIncidentDetail       from '@salesforce/apex/SentinelFlowPortalController.getIncidentDetail';

export default class SentinelFlowPortalTimeline extends LightningElement {

    @api recordId; // Incident__c Id passed in from parent
    @track isLoading = true;
    @track retryLogs = [];
    @track incident  = {};

    // ── Wire: Retry Logs ────────────────────────────────────────────────────
    @wire(getRetryLogsForIncident, { incidentId: '$recordId' })
    wiredRetryLogs({ data, error }) {
        if (data) {
            this.retryLogs = data.map(log => {
                let dotClass = 'tl-dot tl-dot-red';
                let badgeClass = 'tl-badge tl-badge-red';
                
                if (log.Result__c === 'Success') {
                    dotClass = 'tl-dot tl-dot-green';
                    badgeClass = 'tl-badge tl-badge-green';
                } else if (log.Result__c === 'Pending') {
                    dotClass = 'tl-dot tl-dot-yellow';
                    badgeClass = 'tl-badge tl-badge-yellow';
                }
                
                return {
                    ...log,
                    retryDotClass: dotClass,
                    retryBadgeClass: badgeClass,
                    Timestamp__c: log.Timestamp__c
                        ? new Date(log.Timestamp__c).toLocaleString('en-US', {
                            month: 'short', day: 'numeric',
                            hour: '2-digit', minute: '2-digit'
                        })
                        : ''
                };
            });
            this.checkLoading();
        } else if (error) {
            this.retryLogs = [];
            this.checkLoading();
        }
    }

    // ── Wire: Incident Detail ───────────────────────────────────────────────
    @wire(getIncidentDetail, { recordId: '$recordId' })
    wiredIncident({ data, error }) {
        if (data) {
            const d = data;
            this.incident = {
                ...d,
                description:         d.description || '—',
                createdTime:         '—', // CreatedDate not in current DTO; can extend if needed
                hasClassification:   !!(d.rootCause || d.recommendedAction),
                rootCause:           d.rootCause          || 'Pending AI analysis',
                recommendedAction:   d.recommendedAction  || '—',
                aiImpactLevel:       d.aiImpactLevel      || '—',
                aiConfidence:        d.aiConfidence != null ? d.aiConfidence : '—',
                autoHealStatus:      d.autoHealStatus     || 'Not Attempted',
                isResolved:          ['Resolved', 'Closed'].includes(d.status),
                isEscalated:         d.autoHealStatus === 'Escalated',
                resolvedTime:        d.resolvedTime || null
            };
            this.checkLoading();
        } else if (error) {
            this.incident = {};
            this.checkLoading();
        }
    }

    checkLoading() {
        // Mark loading done once both wires have responded
        if (this.retryLogs !== undefined && this.incident !== undefined) {
            this.isLoading = false;
        }
    }

    get isEmpty() {
        return !this.isLoading && this.retryLogs.length === 0 && !this.incident.hasClassification;
    }

    // ── Severity badge ──────────────────────────────────────────────────────
    get severityBadge() {
        const sev = this.incident.severity || '';
        if (sev === 'Critical') return 'tl-badge tl-badge-red';
        if (sev === 'High')     return 'tl-badge tl-badge-orange';
        if (sev === 'Medium')   return 'tl-badge tl-badge-yellow';
        return 'tl-badge tl-badge-blue';
    }

    // CSS classes are precomputed in wiredRetryLogs
}
