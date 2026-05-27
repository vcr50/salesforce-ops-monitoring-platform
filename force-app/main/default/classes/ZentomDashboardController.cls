public with sharing class ZentomDashboardController {
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String dateRange) {
        DashboardData data = new DashboardData();
        data.summary = getDashboardSummary(dateRange);
        data.recentIncidents = getRecentIncidents(dateRange);
        data.riskDistribution = getRiskDistribution(dateRange);
        data.pendingApprovals = getPendingApprovalRows(dateRange);
        data.recentExecutions = getRecentExecutions(dateRange);
        data.recentReplayEvents = getRecentReplayEvents(dateRange);
        data.recentCasesCreated = getRecentCasesCreated(dateRange);
        return data;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardSummary getDashboardSummary(String dateRange) {
        List<Sentinel_Incident__c> incidents = queryIncidents(dateRange, 2000);
        DashboardSummary summary = new DashboardSummary();
        summary.totalIncidents = incidents.size();
        summary.recentReplayEvents = getReplayEventCount(dateRange);

        Map<String, Integer> runbookCounts = new Map<String, Integer>();
        for (Sentinel_Incident__c incident : incidents) {
            if (incident.Risk_Level__c == 'CRITICAL') {
                summary.criticalIncidents++;
            }
            if (incident.Approval_Status__c == 'Pending Approval') {
                summary.pendingApprovals++;
            }
            if (incident.Execution_Status__c == 'Executed') {
                summary.executedActions++;
            }
            if (incident.Recommendation_Status__c == 'Rejected') {
                summary.rejectedRecommendations++;
            }
            if (incident.Created_Case__c != null) {
                summary.recentCasesCreated++;
            }
            if (incident.Status__c == 'Approval Required') {
                summary.approvalRequired++;
            }
            if (!String.isBlank(incident.Runbook_Key__c)) {
                Integer current = runbookCounts.containsKey(incident.Runbook_Key__c)
                    ? runbookCounts.get(incident.Runbook_Key__c)
                    : 0;
                runbookCounts.put(incident.Runbook_Key__c, current + 1);
            }
        }

        Integer topCount = 0;
        for (String runbookKey : runbookCounts.keySet()) {
            if (runbookCounts.get(runbookKey) > topCount) {
                topCount = runbookCounts.get(runbookKey);
                summary.topRunbook = runbookKey;
            }
        }

        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<IncidentRow> getRecentIncidents(String dateRange) {
        return toIncidentRows(queryIncidents(dateRange, 8));
    }

    @AuraEnabled(cacheable=true)
    public static List<RiskBucket> getRiskDistribution(String dateRange) {
        Map<String, Integer> counts = new Map<String, Integer>{
            'CRITICAL' => 0,
            'HIGH' => 0,
            'MEDIUM' => 0,
            'LOW' => 0
        };

        for (Sentinel_Incident__c incident : queryIncidents(dateRange, 2000)) {
            String riskLevel = String.isBlank(incident.Risk_Level__c) ? 'UNKNOWN' : incident.Risk_Level__c;
            counts.put(riskLevel, counts.containsKey(riskLevel) ? counts.get(riskLevel) + 1 : 1);
        }

        List<RiskBucket> buckets = new List<RiskBucket>();
        for (String riskLevel : counts.keySet()) {
            RiskBucket bucket = new RiskBucket();
            bucket.riskLevel = riskLevel;
            bucket.count = counts.get(riskLevel);
            buckets.add(bucket);
        }
        return buckets;
    }

    @AuraEnabled(cacheable=true)
    public static List<IncidentRow> getPendingApprovalRows(String dateRange) {
        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c,
                Policy_Decision__c, Recommendation_Status__c, Status__c,
                Approval_Status__c, Execution_Status__c, Execution_Action__c,
                Execution_Result__c, Executed_At__c, Runbook_Key__c,
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate
            FROM Sentinel_Incident__c
            WHERE Approval_Status__c = 'Pending Approval'
            ORDER BY CreatedDate DESC
            LIMIT 6
        ];
        return toIncidentRows(filterByDate(incidents, dateRange));
    }

    @AuraEnabled(cacheable=true)
    public static List<IncidentRow> getRecentExecutions(String dateRange) {
        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c,
                Policy_Decision__c, Recommendation_Status__c, Status__c,
                Approval_Status__c, Execution_Status__c, Execution_Action__c,
                Execution_Result__c, Executed_At__c, Runbook_Key__c,
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate
            FROM Sentinel_Incident__c
            WHERE Execution_Status__c = 'Executed'
            ORDER BY Executed_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 6
        ];
        return toIncidentRows(filterByDate(incidents, dateRange));
    }

    @AuraEnabled(cacheable=true)
    public static List<ReplayEventRow> getRecentReplayEvents(String dateRange) {
        Datetime cutoff = getCutoff(dateRange);
        List<Sentinel_Audit_Log__c> logs;
        if (cutoff == null) {
            logs = [
                SELECT Id, Event_Type__c, Decision__c, Trace_Id__c, Incident__c,
                    Incident__r.Name, CreatedDate, CreatedBy.Name
                FROM Sentinel_Audit_Log__c
                ORDER BY CreatedDate DESC
                LIMIT 8
            ];
        } else {
            logs = [
                SELECT Id, Event_Type__c, Decision__c, Trace_Id__c, Incident__c,
                    Incident__r.Name, CreatedDate, CreatedBy.Name
                FROM Sentinel_Audit_Log__c
                WHERE CreatedDate >= :cutoff
                ORDER BY CreatedDate DESC
                LIMIT 8
            ];
        }

        List<ReplayEventRow> rows = new List<ReplayEventRow>();
        for (Sentinel_Audit_Log__c log : logs) {
            ReplayEventRow row = new ReplayEventRow();
            row.id = log.Id;
            row.eventType = log.Event_Type__c;
            row.decision = log.Decision__c;
            row.traceId = log.Trace_Id__c;
            row.incidentId = log.Incident__c;
            row.incidentName = log.Incident__r != null ? log.Incident__r.Name : null;
            row.createdDate = log.CreatedDate;
            row.createdByName = log.CreatedBy.Name;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<IncidentRow> getRecentCasesCreated(String dateRange) {
        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c,
                Policy_Decision__c, Recommendation_Status__c, Status__c,
                Approval_Status__c, Execution_Status__c, Execution_Action__c,
                Execution_Result__c, Executed_At__c, Runbook_Key__c,
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate
            FROM Sentinel_Incident__c
            WHERE Created_Case__c != null
            ORDER BY Executed_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 6
        ];
        return toIncidentRows(filterByDate(incidents, dateRange));
    }

    private static List<Sentinel_Incident__c> queryIncidents(String dateRange, Integer rowLimit) {
        Datetime cutoff = getCutoff(dateRange);
        if (cutoff == null) {
            return [
                SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c,
                    Policy_Decision__c, Recommendation_Status__c, Status__c,
                    Approval_Status__c, Execution_Status__c, Execution_Action__c,
                    Execution_Result__c, Executed_At__c, Runbook_Key__c,
                    Created_Case__c, Created_Case__r.CaseNumber, CreatedDate
                FROM Sentinel_Incident__c
                ORDER BY CreatedDate DESC
                LIMIT :rowLimit
            ];
        }

        return [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c,
                Policy_Decision__c, Recommendation_Status__c, Status__c,
                Approval_Status__c, Execution_Status__c, Execution_Action__c,
                Execution_Result__c, Executed_At__c, Runbook_Key__c,
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate
            FROM Sentinel_Incident__c
            WHERE CreatedDate >= :cutoff
            ORDER BY CreatedDate DESC
            LIMIT :rowLimit
        ];
    }

    private static List<Sentinel_Incident__c> filterByDate(
        List<Sentinel_Incident__c> incidents,
        String dateRange
    ) {
        Datetime cutoff = getCutoff(dateRange);
        if (cutoff == null) {
            return incidents;
        }

        List<Sentinel_Incident__c> filtered = new List<Sentinel_Incident__c>();
        for (Sentinel_Incident__c incident : incidents) {
            if (incident.CreatedDate >= cutoff) {
                filtered.add(incident);
            }
        }
        return filtered;
    }

    private static Datetime getCutoff(String dateRange) {
        if (dateRange == 'TODAY') {
            return Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        }
        if (dateRange == 'ALL') {
            return null;
        }
        return System.now().addDays(-7);
    }

    private static Integer getReplayEventCount(String dateRange) {
        Datetime cutoff = getCutoff(dateRange);
        if (cutoff == null) {
            return [SELECT COUNT() FROM Sentinel_Audit_Log__c];
        }
        return [SELECT COUNT() FROM Sentinel_Audit_Log__c WHERE CreatedDate >= :cutoff];
    }

    private static List<IncidentRow> toIncidentRows(List<Sentinel_Incident__c> incidents) {
        List<IncidentRow> rows = new List<IncidentRow>();
        for (Sentinel_Incident__c incident : incidents) {
            IncidentRow row = new IncidentRow();
            row.id = incident.Id;
            row.name = incident.Name;
            row.incidentType = incident.Incident_Type__c;
            row.riskLevel = incident.Risk_Level__c;
            row.riskScore = incident.Risk_Score__c;
            row.policyDecision = incident.Policy_Decision__c;
            row.recommendationStatus = incident.Recommendation_Status__c;
            row.status = incident.Status__c;
            row.approvalStatus = incident.Approval_Status__c;
            row.executionStatus = incident.Execution_Status__c;
            row.executionAction = incident.Execution_Action__c;
            row.executionResult = incident.Execution_Result__c;
            row.executedAt = incident.Executed_At__c;
            row.runbookKey = incident.Runbook_Key__c;
            row.createdCaseId = incident.Created_Case__c;
            row.createdCaseNumber = incident.Created_Case__r != null
                ? incident.Created_Case__r.CaseNumber
                : null;
            row.createdDate = incident.CreatedDate;
            rows.add(row);
        }
        return rows;
    }

    public class DashboardData {
        @AuraEnabled public DashboardSummary summary;
        @AuraEnabled public List<IncidentRow> recentIncidents;
        @AuraEnabled public List<RiskBucket> riskDistribution;
        @AuraEnabled public List<IncidentRow> pendingApprovals;
        @AuraEnabled public List<IncidentRow> recentExecutions;
        @AuraEnabled public List<ReplayEventRow> recentReplayEvents;
        @AuraEnabled public List<IncidentRow> recentCasesCreated;
    }

    public class DashboardSummary {
        @AuraEnabled public Integer totalIncidents = 0;
        @AuraEnabled public Integer criticalIncidents = 0;
        @AuraEnabled public Integer pendingApprovals = 0;
        @AuraEnabled public Integer executedActions = 0;
        @AuraEnabled public Integer rejectedRecommendations = 0;
        @AuraEnabled public Integer recentReplayEvents = 0;
        @AuraEnabled public Integer approvalRequired = 0;
        @AuraEnabled public Integer recentCasesCreated = 0;
        @AuraEnabled public String topRunbook;
    }

    public class IncidentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String incidentType;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String policyDecision;
        @AuraEnabled public String recommendationStatus;
        @AuraEnabled public String status;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String executionStatus;
        @AuraEnabled public String executionAction;
        @AuraEnabled public String executionResult;
        @AuraEnabled public Datetime executedAt;
        @AuraEnabled public String runbookKey;
        @AuraEnabled public Id createdCaseId;
        @AuraEnabled public String createdCaseNumber;
        @AuraEnabled public Datetime createdDate;
    }

    public class ReplayEventRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String eventType;
        @AuraEnabled public String decision;
        @AuraEnabled public String traceId;
        @AuraEnabled public Id incidentId;
        @AuraEnabled public String incidentName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }

    public class RiskBucket {
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Integer count;
    }

    
    private static final String BASE_URL = 'https://quick-ads-nail.loca.lt';
    private static final String API_KEY = 'ztm-system-key-v1';
    
    // ─── READ-ONLY ENDPOINTS (cacheable for LWC @wire) ──────────────────
    
    @AuraEnabled(cacheable=true)
    public static String getAnalyticsSummary() {
        return callZentomAPI('/api/v1/analytics/summary');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getPredictions() {
        return callZentomAPI('/api/v1/analytics/predictions');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getDeepHealth() {
        return callZentomAPI('/health/deep');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getPendingApprovals() {
        return callZentomAPI('/api/v1/approvals/pending');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getMetrics() {
        return callZentomAPI('/api/v1/metrics');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getAuditLogs() {
        return callZentomAPI('/api/v1/audit/logs?limit=15');
    }
    
    // ─── MUTATING ENDPOINTS (not cacheable) ─────────────────────────────
    
    @AuraEnabled
    public static String approveWorkflow(Integer workflowId, String approvedBy) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('approved_by', approvedBy);
        return callZentomAPIPost('/api/v1/approvals/' + workflowId + '/approve', JSON.serialize(body));
    }
    
    @AuraEnabled
    public static String rejectWorkflow(Integer workflowId, String reason) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('reason', reason);
        return callZentomAPIPost('/api/v1/approvals/' + workflowId + '/reject', JSON.serialize(body));
    }
    
    // ─── HTTP HELPERS ───────────────────────────────────────────────────
    
    private static String callZentomAPI(String path) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + path);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-Key', API_KEY);
        req.setTimeout(15000);
        
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                return res.getBody();
            }
            return '{"error": "HTTP ' + res.getStatusCode() + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
    
    private static String callZentomAPIPost(String path, String body) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-Key', API_KEY);
        req.setTimeout(15000);
        req.setBody(body);
        
        try {
            HttpResponse res = http.send(req);
            return res.getBody();
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
}