import { LightningElement, track } from 'lwc';
import getAnalyticsSummary from '@salesforce/apex/ZentomDashboardController.getAnalyticsSummary';
import getPredictions from '@salesforce/apex/ZentomDashboardController.getPredictions';
import getDeepHealth from '@salesforce/apex/ZentomDashboardController.getDeepHealth';
import getPendingApprovals from '@salesforce/apex/ZentomDashboardController.getPendingApprovals';
import getMetrics from '@salesforce/apex/ZentomDashboardController.getMetrics';
import getAuditLogs from '@salesforce/apex/ZentomDashboardController.getAuditLogs';
import approveWorkflow from '@salesforce/apex/ZentomDashboardController.approveWorkflow';
import rejectWorkflow from '@salesforce/apex/ZentomDashboardController.rejectWorkflow';

export default class ZentomMissionControl extends LightningElement {
    // ── Analytics
    @track totalWorkflows = '--';
    @track successRate = '--';
    @track avgConfidence = '--';
    @track driftAlerts = '--';
    @track pendingCount = '--';
    @track mttr = '--';

    // ── Health
    @track healthGrade = '--';
    @track healthScore = 0;
    @track healthFactors = [];
    @track subsystems = [];
    @track overallStatus = 'CHECKING';

    // ── Risk Trend
    @track trendDirection = '--';
    @track trendLabel = 'Loading...';
    @track trendDetail = '';
    @track trendColorClass = 'trend-stable';

    // ── Patterns
    @track patterns = [];
    @track patternCount = 0;

    // ── Remediation
    @track remediations = [];

    // ── Approvals
    @track approvals = [];
    @track approvalCount = 0;

    // ── Logs
    @track orchestrationLogs = [];
    @track auditLogs = [];

    // ── Gauge
    @track gaugeStyle = '';
    @track scoreColorStyle = '';

    _timer;

    connectedCallback() {
        this.refreshAll();
        this._timer = setInterval(() => this.refreshAll(), 5000);
    }

    disconnectedCallback() {
        if (this._timer) clearInterval(this._timer);
    }

    async refreshAll() {
        this.loadAnalytics();
        this.loadPredictions();
        this.loadHealth();
        this.loadApprovals();
        this.loadLogs();
        this.loadAudit();
    }

    // ── Analytics ──
    async loadAnalytics() {
        try {
            const raw = await getAnalyticsSummary();
            const d = JSON.parse(raw);
            if (d.error) return;
            this.totalWorkflows = d.totalWorkflows;
            this.successRate = d.successRate;
            this.avgConfidence = d.avgConfidence + '%';
            this.driftAlerts = d.driftAlerts;
            this.pendingCount = d.pendingApprovals;
            const m = d.mttrSeconds;
            this.mttr = m > 0 ? (m < 60 ? m + 's' : Math.round(m / 60) + 'm') : 'N/A';
        } catch (e) { /* silent */ }
    }

    // ── Predictions ──
    async loadPredictions() {
        try {
            const raw = await getPredictions();
            const d = JSON.parse(raw);
            if (d.error) return;

            // Health
            const h = d.orgHealth || {};
            this.healthScore = h.score ?? 0;
            this.healthGrade = h.grade ?? '--';
            const pct = (this.healthScore / 100) * 360;
            const color = this.healthScore >= 80 ? '#34d399' : this.healthScore >= 60 ? '#fbbf24' : '#f87171';
            this.gaugeStyle = `background: conic-gradient(${color} ${pct}deg, rgba(255,255,255,0.05) ${pct}deg)`;
            this.scoreColorStyle = `color: ${color}`;
            this.healthFactors = (h.factors || []).map((f, i) => ({ key: 'f' + i, text: f }));

            // Risk Trend
            const t = d.riskTrend || {};
            if (t.trend === 'INCREASING') {
                this.trendDirection = '\u25B2';
                this.trendLabel = 'INCREASING';
                this.trendColorClass = 'trend-danger';
            } else if (t.trend === 'DECREASING') {
                this.trendDirection = '\u25BC';
                this.trendLabel = 'DECREASING';
                this.trendColorClass = 'trend-success';
            } else if (t.trend === 'STABLE') {
                this.trendDirection = '\u2500';
                this.trendLabel = 'STABLE';
                this.trendColorClass = 'trend-stable';
            } else {
                this.trendDirection = '?';
                this.trendLabel = t.trend || 'N/A';
                this.trendColorClass = 'trend-muted';
            }
            this.trendDetail = t.previousAvgRisk != null
                ? `Avg Risk: ${t.previousAvgRisk} \u2192 ${t.currentAvgRisk} (${t.delta > 0 ? '+' : ''}${t.delta})`
                : '';

            // Patterns
            const pats = d.recurringPatterns || [];
            this.patternCount = pats.length;
            const maxOcc = pats.length > 0 ? Math.max(...pats.map(p => p.occurrences)) : 1;
            this.patterns = pats.map((p, i) => ({
                key: 'p' + i,
                name: p.errorSignature,
                count: p.occurrences + 'x',
                severity: p.severity,
                barWidth: Math.max(10, (p.occurrences / maxOcc) * 100) + '%',
                barClass: 'pattern-bar-fill ' + (p.severity === 'HIGH' ? 'bar-danger' : p.severity === 'MEDIUM' ? 'bar-warning' : 'bar-info')
            }));

            // Remediation
            this.remediations = (d.remediationEffectiveness || []).map((r, i) => ({
                key: 'r' + i,
                action: r.action,
                total: r.totalExecutions,
                rate: r.successRate + '%',
                reliability: r.reliability,
                reliabilityClass: 'pill pill-' + (r.reliability === 'HIGH' ? 'ok' : r.reliability === 'MEDIUM' ? 'warn' : 'bad')
            }));
        } catch (e) { /* silent */ }
    }

    // ── Health ──
    async loadHealth() {
        try {
            const raw = await getDeepHealth();
            const d = JSON.parse(raw);
            if (d.error) return;
            this.overallStatus = d.status === 'UP' ? 'ALL SYSTEMS' : d.status;
            const subs = d.subsystems || {};
            this.subsystems = Object.entries(subs).map(([name, info]) => ({
                key: name,
                name: name,
                detail: info.latencyMs ? info.latencyMs + 'ms' : info.status,
                dotClass: 'dot ' + (info.status === 'UP' ? 'dot-up' : info.status === 'DOWN' ? 'dot-down' : 'dot-warn')
            }));
        } catch (e) { /* silent */ }
    }

    // ── Approvals ──
    async loadApprovals() {
        try {
            const raw = await getPendingApprovals();
            const d = JSON.parse(raw);
            if (d.error) return;
            this.approvalCount = d.count;
            this.approvals = (d.workflows || []).map(w => {
                const exp = new Date(w.expiresAt);
                const rem = Math.max(0, Math.round((exp - Date.now()) / 60000));
                return {
                    key: 'wf' + w.workflowId,
                    workflowId: w.workflowId,
                    incidentId: w.incidentId,
                    proposedAction: w.proposedAction,
                    confidence: w.confidence + '%',
                    confidenceClass: w.confidence >= 80 ? 'score-high' : w.confidence >= 60 ? 'score-med' : 'score-low',
                    riskScore: w.riskScore != null ? w.riskScore.toFixed(1) : '--',
                    policyReasoning: w.policyReasoning || '',
                    ttl: rem + 'm'
                };
            });
        } catch (e) { /* silent */ }
    }

    // ── Orchestration Logs ──
    async loadLogs() {
        try {
            const raw = await getMetrics();
            const d = JSON.parse(raw);
            if (d.error) return;
            this.orchestrationLogs = (d.recent_logs || []).slice(0, 15).map((l, i) => {
                const t = new Date(l.timestamp);
                return {
                    key: 'log' + i,
                    incidentId: l.incident_id,
                    time: t.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
                    action: l.action,
                    confidence: l.confidence + '%',
                    confidenceClass: l.confidence >= 80 ? 'score-high' : l.confidence >= 60 ? 'score-med' : 'score-low',
                    statusPill: l.success ? 'pill pill-ok' : 'pill pill-warn',
                    statusText: l.success ? 'OK' : 'EVAL'
                };
            });
        } catch (e) { /* silent */ }
    }

    // ── Audit ──
    async loadAudit() {
        try {
            const raw = await getAuditLogs();
            const d = JSON.parse(raw);
            if (d.error) return;
            this.auditLogs = (d.logs || []).map((l, i) => ({
                key: 'a' + i,
                time: l.timestamp ? new Date(l.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '',
                eventType: l.eventType,
                eventClass: 'pill pill-' + (l.eventType === 'APPROVE' ? 'ok' : l.eventType === 'REJECT' ? 'bad' : 'info'),
                actor: l.actor,
                role: l.role || '',
                resource: l.resource || ''
            }));
        } catch (e) { /* silent */ }
    }

    // ── Actions ──
    handleApprove(event) {
        const wfId = event.target.dataset.id;
        // eslint-disable-next-line no-alert
        const by = prompt('Approved by:');
        if (!by) return;
        approveWorkflow({ workflowId: parseInt(wfId, 10), approvedBy: by })
            .then(() => this.refreshAll());
    }

    handleReject(event) {
        const wfId = event.target.dataset.id;
        // eslint-disable-next-line no-alert
        const reason = prompt('Rejection reason:');
        if (!reason) return;
        rejectWorkflow({ workflowId: parseInt(wfId, 10), reason: reason })
            .then(() => this.refreshAll());
    }

    // ── Computed ──
    get hasPatterns() { return this.patterns.length > 0; }
    get hasRemediations() { return this.remediations.length > 0; }
    get hasApprovals() { return this.approvals.length > 0; }
    get hasLogs() { return this.orchestrationLogs.length > 0; }
    get hasAuditLogs() { return this.auditLogs.length > 0; }
    get hasHealthFactors() { return this.healthFactors.length > 0; }
    get hasSubsystems() { return this.subsystems.length > 0; }
}