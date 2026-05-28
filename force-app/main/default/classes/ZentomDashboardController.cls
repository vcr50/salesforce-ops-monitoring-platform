public with sharing class ZentomDashboardController {
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String dateRange) {
        DashboardData data = new DashboardData();
        
        List<Sentinel_Incident__c> recentForAi = [SELECT AI_Reasoning_Status__c, AI_Confidence__c FROM Sentinel_Incident__c WHERE AI_Reasoning_Status__c != null ORDER BY CreatedDate DESC LIMIT 1];
        if (!recentForAi.isEmpty()) {
            AiSignal signal = new AiSignal();
            signal.aiStatus = recentForAi[0].AI_Reasoning_Status__c;
            signal.confidenceScore = recentForAi[0].AI_Confidence__c != null ? Integer.valueOf(recentForAi[0].AI_Confidence__c) : null;
            data.latestAiSignal = signal;
        }

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
        summary.errorLogCount = getErrorLogCount(dateRange);
        Integer criticalOpen = 0;
        Integer pendingApp = 0;
        Integer rejectedRec = 0;
        Integer failedExec = 0;
        Integer aiConfidenceSum = 0;
        Integer aiConfidenceCount = 0;

        Map<String, Integer> runbookCounts = new Map<String, Integer>();
        for (Sentinel_Incident__c incident : incidents) {
            if (incident.Risk_Level__c == 'CRITICAL') {
                summary.criticalIncidents++;
            }
            if (incident.Approval_Status__c == 'Pending Approval') {
                summary.pendingApprovals++;
                pendingApp++;
            }
            if (incident.Execution_Status__c == 'Executed') {
                summary.executedActions++;
            }
            if (incident.Recommendation_Status__c == 'Rejected') {
                summary.rejectedRecommendations++;
                rejectedRec++;
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
            if (incident.AI_Confidence__c != null) {
                aiConfidenceSum += Integer.valueOf(incident.AI_Confidence__c);
                aiConfidenceCount++;
            }

            // Health Score data gathering
            if (incident.Risk_Level__c == 'CRITICAL' && incident.Status__c != 'Closed' && incident.Status__c != 'Action Created' && incident.Status__c != 'Resolved') {
                criticalOpen++;
            }
            if (incident.Execution_Status__c == 'Failed') {
                failedExec++;
            }
        }

        Integer topCount = 0;
        for (String runbookKey : runbookCounts.keySet()) {
            if (runbookCounts.get(runbookKey) > topCount) {
                topCount = runbookCounts.get(runbookKey);
                summary.topRunbook = runbookKey;
            }
        }
        
        if (aiConfidenceCount > 0) {
            summary.avgAiConfidence = aiConfidenceSum / aiConfidenceCount;
        } else {
            summary.avgAiConfidence = 0;
        }

        // Calculate orgHealthScore
        Integer score = 100;
        List<String> reasons = new List<String>();

        if (criticalOpen > 0) {
            score -= (criticalOpen * 10);
            reasons.add(criticalOpen + (criticalOpen == 1 ? ' critical open incident' : ' critical open incidents'));
        }
        if (pendingApp > 0) {
            score -= (pendingApp * 8);
            reasons.add(pendingApp + (pendingApp == 1 ? ' pending approval' : ' pending approvals'));
        }
        if (failedExec > 0) {
            score -= (failedExec * 12);
            reasons.add(failedExec + (failedExec == 1 ? ' failed execution' : ' failed executions'));
        }
        if (rejectedRec > 0) {
            score -= (rejectedRec * 5);
            reasons.add(rejectedRec + (rejectedRec == 1 ? ' rejected recommendation' : ' rejected recommendations'));
        }

        if (score < 0) score = 0;
        summary.orgHealthScore = score;

        if (score >= 90) summary.orgHealthStatus = 'Healthy';
        else if (score >= 70) summary.orgHealthStatus = 'Stable';
        else summary.orgHealthStatus = 'Critical';

        if (reasons.isEmpty()) {
            summary.orgHealthReason = 'No active incidents are reducing the org health score.';
        } else {
            summary.orgHealthReason = 'Reduced by: ' + String.join(reasons, ', ');
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
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate,
                Environment__c, AI_Confidence__c, AI_Reasoning_Status__c
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
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate,
                Environment__c, AI_Confidence__c, AI_Reasoning_Status__c
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
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate,
                Environment__c, AI_Confidence__c, AI_Reasoning_Status__c
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
                    Created_Case__c, Created_Case__r.CaseNumber, CreatedDate,
                    Environment__c, AI_Confidence__c, AI_Reasoning_Status__c
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
                Created_Case__c, Created_Case__r.CaseNumber, CreatedDate,
                Environment__c, AI_Confidence__c, AI_Reasoning_Status__c
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

    private static Integer getErrorLogCount(String dateRange) {
        Datetime cutoff = getCutoff(dateRange);
        if (cutoff == null) {
            return [SELECT COUNT() FROM Sentinel_Audit_Log__c WHERE Decision__c IN ('Failed', 'Error', 'Exception') OR Event_Type__c IN ('Error', 'Exception')];
        }
        return [SELECT COUNT() FROM Sentinel_Audit_Log__c WHERE CreatedDate >= :cutoff AND (Decision__c IN ('Failed', 'Error', 'Exception') OR Event_Type__c IN ('Error', 'Exception'))];
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
            row.environment = incident.Environment__c;
            row.aiConfidence = incident.AI_Confidence__c;
            row.aiStatus = incident.AI_Reasoning_Status__c;
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
        @AuraEnabled public AiSignal latestAiSignal;
    }

    public class AiSignal {
        @AuraEnabled public String aiStatus;
        @AuraEnabled public Integer confidenceScore;
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
        @AuraEnabled public Integer avgAiConfidence = 0;
        @AuraEnabled public Integer errorLogCount = 0;
        @AuraEnabled public String topRunbook;
        @AuraEnabled public Integer orgHealthScore = 100;
        @AuraEnabled public String orgHealthStatus = 'Healthy';
        @AuraEnabled public String orgHealthReason = 'No active incidents are reducing the org health score.';
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
        @AuraEnabled public String environment;
        @AuraEnabled public Decimal aiConfidence;
        @AuraEnabled public String aiStatus;
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

    
    // ─── NATIVE ENDPOINTS FOR DASHBOARD ─────────────────────────────
    
    @AuraEnabled(cacheable=true)
    public static String getAnalyticsSummary() {
        return '{"summary": "Native analytics active."}'; // Stubbed for native logic
    }
    
    @AuraEnabled(cacheable=true)
    public static String getPredictions() {
        return '{"predictions": []}';
    }
    
    @AuraEnabled(cacheable=true)
    public static String getDeepHealth() {
        return '{"status": "Healthy"}';
    }
    
    @AuraEnabled(cacheable=true)
    public static String getMetrics() {
        return '{"metrics": {}}';
    }
    
    @AuraEnabled(cacheable=true)
    public static String getAuditLogs() {
        return '{"logs": []}';
    }

    // ─── NATIVE APPROVAL QUEUE (GUARDIAN GATE) ─────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ZentomApprovalRow> getPendingApprovals() {
        if (!Schema.sObjectType.Sentinel_Incident__c.isAccessible()) {
            return new List<ZentomApprovalRow>();
        }
        
        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c, 
                   AI_Confidence__c, AI_Reasoning_Status__c, CreatedDate, Execution_Action__c
            FROM Sentinel_Incident__c
            WHERE Approval_Status__c = 'Pending Approval'
            ORDER BY CreatedDate ASC
        ];
        
        List<ZentomApprovalRow> rows = new List<ZentomApprovalRow>();
        for (Sentinel_Incident__c inc : incidents) {
            ZentomApprovalRow row = new ZentomApprovalRow();
            row.id = inc.Id;
            row.incidentId = inc.Name;
            row.proposedAction = String.isNotBlank(inc.Execution_Action__c) ? inc.Execution_Action__c : 'Autonomous Remediation';
            row.confidence = inc.AI_Confidence__c != null ? Integer.valueOf(inc.AI_Confidence__c) : 85;
            row.riskScore = inc.Risk_Score__c != null ? inc.Risk_Score__c : 7.5;
            row.policyReasoning = String.isNotBlank(inc.AI_Reasoning_Status__c) ? inc.AI_Reasoning_Status__c : 'Risk exceeds autonomous threshold.';
            // Add TTL dynamically for UI based on creation time (4 hours expiry)
            row.expiresAt = inc.CreatedDate.addHours(4).getTime();
            rows.add(row);
        }
        return rows;
    }
    
    public class ZentomApprovalRow {
        @AuraEnabled public String id;
        @AuraEnabled public String incidentId;
        @AuraEnabled public String proposedAction;
        @AuraEnabled public Integer confidence;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String policyReasoning;
        @AuraEnabled public Long expiresAt;
    }
    
    @AuraEnabled
    public static String approveWorkflow(String incidentId, String approvedBy) {
        try {
            if (!Schema.sObjectType.Sentinel_Incident__c.isUpdateable() || 
                !Schema.sObjectType.Zentom_Policy_Decision__c.isCreateable()) {
                return '{"error": "Insufficient permissions to approve incident."}';
            }
            
            List<Sentinel_Incident__c> incidents = [
                SELECT Id, Status__c, Approval_Status__c, Name 
                FROM Sentinel_Incident__c 
                WHERE Id = :incidentId
            ];
            
            if (incidents.isEmpty()) {
                return '{"error": "Incident not found."}';
            }
            
            Sentinel_Incident__c inc = incidents[0];
            if (inc.Approval_Status__c == 'Approved' || inc.Approval_Status__c == 'Rejected') {
                return '{"error": "Incident is already processed."}';
            }
            
            inc.Approval_Status__c = 'Approved';
            inc.Status__c = 'Approved';
            inc.Execution_Status__c = 'Ready for Execution';
            inc.Approved_By__c = UserInfo.getUserId();
            inc.Approved_At__c = System.now();
            update inc;
            
            Zentom_Policy_Decision__c decision = new Zentom_Policy_Decision__c();
            decision.Incident__c = inc.Id;
            decision.Decision__c = 'Approved';
            decision.Reason__c = 'Approved by ' + approvedBy;
            decision.Action_Type__c = 'Runbook Execution';
            insert decision;
            
            return '{"success": true, "incidentId": "' + inc.Name + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
    
    @AuraEnabled
    public static String rejectWorkflow(String incidentId, String reason) {
        try {
            if (!Schema.sObjectType.Sentinel_Incident__c.isUpdateable() || 
                !Schema.sObjectType.Zentom_Policy_Decision__c.isCreateable()) {
                return '{"error": "Insufficient permissions to reject incident."}';
            }
            
            List<Sentinel_Incident__c> incidents = [
                SELECT Id, Status__c, Approval_Status__c, Name 
                FROM Sentinel_Incident__c 
                WHERE Id = :incidentId
            ];
            
            if (incidents.isEmpty()) {
                return '{"error": "Incident not found."}';
            }
            
            Sentinel_Incident__c inc = incidents[0];
            if (inc.Approval_Status__c == 'Approved' || inc.Approval_Status__c == 'Rejected') {
                return '{"error": "Incident is already processed."}';
            }
            
            inc.Approval_Status__c = 'Rejected';
            inc.Status__c = 'Analyzed';
            inc.Execution_Status__c = 'Not Started';
            update inc;
            
            Zentom_Policy_Decision__c decision = new Zentom_Policy_Decision__c();
            decision.Incident__c = inc.Id;
            decision.Decision__c = 'Rejected';
            decision.Reason__c = reason;
            decision.Action_Type__c = 'Runbook Execution Cancelled';
            insert decision;
            
            return '{"success": true, "incidentId": "' + inc.Name + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }

    // ─── NATIVE ACTION CENTER QUEUE (EXECUTION GATE) ─────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ZentomActionRow> getPendingActions() {
        if (!Schema.sObjectType.Sentinel_Incident__c.isAccessible()) {
            return new List<ZentomActionRow>();
        }
        
        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c, 
                   AI_Confidence__c, Runbook_Key__c, Execution_Action__c, Approved_By__r.Name
            FROM Sentinel_Incident__c
            WHERE Approval_Status__c = 'Approved' 
              AND Execution_Status__c = 'Ready for Execution'
            ORDER BY CreatedDate ASC
        ];
        
        List<ZentomActionRow> rows = new List<ZentomActionRow>();
        for (Sentinel_Incident__c inc : incidents) {
            ZentomActionRow row = new ZentomActionRow();
            row.id = inc.Id;
            row.incidentId = inc.Name;
            row.incidentType = inc.Incident_Type__c;
            row.action = String.isNotBlank(inc.Execution_Action__c) ? inc.Execution_Action__c : 'Execute Runbook';
            row.runbook = inc.Runbook_Key__c;
            row.confidence = inc.AI_Confidence__c != null ? Integer.valueOf(inc.AI_Confidence__c) : 85;
            row.riskScore = inc.Risk_Score__c != null ? inc.Risk_Score__c : 7.5;
            row.approvedBy = inc.Approved_By__r != null ? inc.Approved_By__r.Name : 'System Admin';
            rows.add(row);
        }
        return rows;
    }

    public class ZentomActionRow {
        @AuraEnabled public String id;
        @AuraEnabled public String incidentId;
        @AuraEnabled public String incidentType;
        @AuraEnabled public String action;
        @AuraEnabled public String runbook;
        @AuraEnabled public Integer confidence;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String approvedBy;
    }

    @AuraEnabled
    public static String executeApprovedAction(String incidentId, String executedBy) {
        try {
            if (!Schema.sObjectType.Sentinel_Incident__c.isUpdateable() || 
                !Schema.sObjectType.Case.isCreateable() ||
                !Schema.sObjectType.Zentom_Policy_Decision__c.isCreateable()) {
                return '{"error": "Insufficient permissions to execute action."}';
            }
            
            List<Sentinel_Incident__c> incidents = [
                SELECT Id, Status__c, Approval_Status__c, Execution_Status__c, Name, Runbook_Key__c 
                FROM Sentinel_Incident__c 
                WHERE Id = :incidentId
            ];
            
            if (incidents.isEmpty()) {
                return '{"error": "Incident not found."}';
            }
            
            Sentinel_Incident__c inc = incidents[0];
            
            if (inc.Approval_Status__c != 'Approved') {
                return '{"error": "Incident must be approved before execution."}';
            }
            
            if (inc.Execution_Status__c == 'Executed') {
                return '{"error": "Incident has already been executed."}';
            }
            
            if (inc.Execution_Status__c != 'Ready for Execution') {
                return '{"error": "Incident is not ready for execution."}';
            }
            
            // Create Case
            Case c = new Case(
                Subject = 'SentinelFlow Execution: ' + inc.Name + (String.isNotBlank(inc.Runbook_Key__c) ? ' - ' + inc.Runbook_Key__c : ''),
                Status = 'New',
                Origin = 'Web'
            );
            insert c;
            
            // Fetch case number
            Case createdCase = [SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];
            
            // Update Incident
            inc.Execution_Status__c = 'Executed';
            inc.Status__c = 'Closed';
            inc.Execution_Result__c = 'Case created';
            inc.Executed_At__c = System.now();
            inc.Created_Case__c = c.Id;
            update inc;
            
            // Audit Log
            Zentom_Policy_Decision__c decision = new Zentom_Policy_Decision__c();
            decision.Incident__c = inc.Id;
            decision.Decision__c = 'Executed';
            decision.Reason__c = 'Executed by ' + executedBy + '. Case ' + createdCase.CaseNumber + ' created.';
            decision.Action_Type__c = 'Runbook Execution Completed';
            insert decision;
            
            return '{"success": true, "incidentId": "' + inc.Name + '", "caseNumber": "' + createdCase.CaseNumber + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
}