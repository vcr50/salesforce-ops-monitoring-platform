public with sharing class ZentomDashboardController {
    private static final Integer ESCALATION_THRESHOLD_HOURS = SystemSettings.getInt('Escalation_Threshold_Hours', 4);

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

        List<Sentinel_Incident__c> criticals = [
            SELECT Id, Name, Incident_Type__c, AI_Summary__c, Recommended_Action__c, Runbook_Key__c 
            FROM Sentinel_Incident__c 
            WHERE Risk_Level__c = 'Critical' OR Risk_Level__c = 'CRITICAL'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        if (!criticals.isEmpty()) {
            data.latestCriticalIncident = criticals[0];
        }

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

    private static Boolean isValidSortField(String fieldName) {
        Set<String> whitelistedFields = new Set<String>{
            'Name',
            'Incident_Type__c',
            'Environment__c',
            'Risk_Level__c',
            'Policy_Decision__c',
            'Status__c',
            'Runbook_Key__c',
            'Approval_Status__c',
            'CreatedDate'
        };
        return whitelistedFields.contains(fieldName);
    }

    @AuraEnabled(cacheable=true)
    public static PaginatedResult getPaginatedIncidents(PaginatedRequest req) {
        if (req == null) {
            return new PaginatedResult();
        }
        // 1. Sanitize and validate inputs
        Integer limitVal = (req.pageSize != null && req.pageSize > 0 && req.pageSize <= 100) ? req.pageSize : 25;
        Integer pageNum = (req.pageNumber != null && req.pageNumber > 0) ? req.pageNumber : 1;
        Integer offsetVal = (pageNum - 1) * limitVal;
        
        // Safety guard: Enforce Salesforce maximum offset constraint of 2000
        if (offsetVal > 2000) {
            offsetVal = 2000;
        }
        
        String sortByField = 'CreatedDate';
        if (String.isNotBlank(req.sortBy) && isValidSortField(req.sortBy)) {
            sortByField = req.sortBy;
        }
        
        String sortDir = 'DESC';
        if (String.isNotBlank(req.sortDirection) && (req.sortDirection.toUpperCase() == 'ASC' || req.sortDirection.toUpperCase() == 'DESC')) {
            sortDir = req.sortDirection.toUpperCase();
        }
        
        // 2. Build WHERE clause with bind variables
        List<String> conditions = new List<String>();
        
        // Date filter
        Datetime cutoff = getCutoff(req.dateRange);
        if (cutoff != null) {
            conditions.add('CreatedDate >= :cutoff');
        }
        // Field filters
        String riskLevel = req.riskLevel;
        if (String.isNotBlank(riskLevel) && riskLevel != 'ALL') {
            conditions.add('Risk_Level__c = :riskLevel');
        }
        String status = req.status;
        if (String.isNotBlank(status) && status != 'ALL') {
            conditions.add('Status__c = :status');
        }
        String environment = req.environment;
        if (String.isNotBlank(environment) && environment != 'ALL') {
            conditions.add('Environment__c = :environment');
        }
        String incidentType = req.incidentType;
        if (String.isNotBlank(incidentType) && incidentType != 'ALL') {
            conditions.add('Incident_Type__c = :incidentType');
        }
        String aiStatus = req.aiStatus;
        if (String.isNotBlank(aiStatus) && aiStatus != 'ALL') {
            if (aiStatus == 'HIGH_CONFIDENCE') {
                conditions.add('AI_Confidence__c > 80');
            } else if (aiStatus == 'REVIEW_NEEDED') {
                conditions.add('AI_Confidence__c <= 80');
            } else if (aiStatus == 'ACTIVE') {
                conditions.add('AI_Reasoning_Status__c = \'ACTIVE\'');
            }
        }
        
        String whereClause = conditions.isEmpty() ? '' : 'WHERE ' + String.join(conditions, ' AND ');
        
        // 3. Execute COUNT Query
        String countQuery = 'SELECT COUNT() FROM Sentinel_Incident__c ' + whereClause;
        Integer totalCount = Database.countQuery(countQuery);
        
        // 4. Execute Paginated Query
        String dataQuery = 'SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c, ' +
                           'Policy_Decision__c, Recommendation_Status__c, Status__c, ' +
                           'Approval_Status__c, Execution_Status__c, Execution_Action__c, ' +
                           'Execution_Result__c, Executed_At__c, Runbook_Key__c, ' +
                           'Created_Case__c, Created_Case__r.CaseNumber, CreatedDate, ' +
                           'Environment__c, AI_Confidence__c, AI_Reasoning_Status__c ' +
                           'FROM Sentinel_Incident__c ' +
                           whereClause + ' ' +
                           'ORDER BY ' + sortByField + ' ' + sortDir + ', Id DESC ' +
                           'LIMIT :limitVal OFFSET :offsetVal';
                           
        List<Sentinel_Incident__c> incidents = Database.query(dataQuery);
        
        // 5. Package results
        PaginatedResult result = new PaginatedResult();
        result.records = toIncidentRows(incidents);
        result.totalRecords = totalCount;
        result.pageNumber = pageNum;
        result.totalPages = (totalCount == 0) ? 0 : (Integer)Math.ceil((Double)totalCount / limitVal);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static KeysetPaginatedResult getKeysetPaginatedIncidents(KeysetPaginatedRequest req) {
        if (req == null) {
            return new KeysetPaginatedResult();
        }
        
        Integer limitVal = (req.pageSize != null && req.pageSize > 0 && req.pageSize <= 100) ? req.pageSize : 25;
        String sortByField = 'CreatedDate';
        if (String.isNotBlank(req.sortBy) && isValidSortField(req.sortBy)) {
            sortByField = req.sortBy;
        }
        
        String sortDir = 'DESC';
        if (String.isNotBlank(req.sortDirection) && (req.sortDirection.toUpperCase() == 'ASC' || req.sortDirection.toUpperCase() == 'DESC')) {
            sortDir = req.sortDirection.toUpperCase();
        }
        
        // 1. Build WHERE conditions for filters (WITHOUT keyset pagination cursor)
        List<String> baseConditions = new List<String>();
        FilterWrapper filters = req.filters;
        Datetime cutoff = null;
        String riskLevel = null;
        String status = null;
        String environment = null;
        String incidentType = null;
        String aiStatus = null;
        
        if (filters != null) {
            cutoff = getCutoff(filters.dateRange);
            if (cutoff != null) {
                baseConditions.add('CreatedDate >= :cutoff');
            }
            riskLevel = filters.riskLevel;
            if (String.isNotBlank(riskLevel) && riskLevel != 'ALL') {
                baseConditions.add('Risk_Level__c = :riskLevel');
            }
            status = filters.status;
            if (String.isNotBlank(status) && status != 'ALL') {
                baseConditions.add('Status__c = :status');
            }
            environment = filters.environment;
            if (String.isNotBlank(environment) && environment != 'ALL') {
                baseConditions.add('Environment__c = :environment');
            }
            incidentType = filters.incidentType;
            if (String.isNotBlank(incidentType) && incidentType != 'ALL') {
                baseConditions.add('Incident_Type__c = :incidentType');
            }
            aiStatus = filters.aiStatus;
            if (String.isNotBlank(aiStatus) && aiStatus != 'ALL') {
                if (aiStatus == 'HIGH_CONFIDENCE') {
                    baseConditions.add('AI_Confidence__c > 80');
                } else if (aiStatus == 'REVIEW_NEEDED') {
                    baseConditions.add('AI_Confidence__c <= 80');
                } else if (aiStatus == 'ACTIVE') {
                    baseConditions.add('AI_Reasoning_Status__c = \'ACTIVE\'');
                }
            }
        }
        
        String countWhereClause = baseConditions.isEmpty() ? '' : 'WHERE ' + String.join(baseConditions, ' AND ');
        
        // 2. Execute COUNT Query (strictly with filter conditions only, no keyset)
        String countQuery = 'SELECT COUNT() FROM Sentinel_Incident__c ' + countWhereClause;
        Integer totalCount = Database.countQuery(countQuery);
        
        // 3. Build data query conditions (including keyset cursor condition if applicable)
        List<String> dataConditions = new List<String>(baseConditions);
        
        Datetime cursorCreatedDate = null;
        String cursorId = null;
        Boolean isKeysetApplied = false;
        
        if (String.isNotBlank(req.direction) && sortByField == 'CreatedDate') {
            if (req.direction == 'NEXT' && String.isNotBlank(req.nextCursorId) && String.isNotBlank(req.nextCursorCreatedDate)) {
                cursorId = req.nextCursorId;
                cursorCreatedDate = (Datetime)parseCursorValue('CreatedDate', req.nextCursorCreatedDate);
                isKeysetApplied = true;
            } else if (req.direction == 'PREV' && String.isNotBlank(req.previousCursorId) && String.isNotBlank(req.previousCursorCreatedDate)) {
                cursorId = req.previousCursorId;
                cursorCreatedDate = (Datetime)parseCursorValue('CreatedDate', req.previousCursorCreatedDate);
                isKeysetApplied = true;
            }
        }
        
        if (isKeysetApplied) {
            Boolean lookForSmaller = false;
            if (req.direction == 'NEXT' && sortDir == 'DESC') lookForSmaller = true;
            if (req.direction == 'PREV' && sortDir == 'ASC') lookForSmaller = true;
            
            String op = lookForSmaller ? '<' : '>';
            dataConditions.add('(CreatedDate ' + op + ' :cursorCreatedDate OR (CreatedDate = :cursorCreatedDate AND Id ' + op + ' :cursorId))');
        }
        
        String dataWhereClause = dataConditions.isEmpty() ? '' : 'WHERE ' + String.join(dataConditions, ' AND ');
        
        // Determine sorting direction for database query
        String querySortDir = sortDir;
        if (req.direction == 'PREV' && isKeysetApplied) {
            querySortDir = (sortDir == 'DESC') ? 'ASC' : 'DESC';
        }
        
        String dataQuery = '';
        Integer offsetVal = 0;
        
        if (sortByField != 'CreatedDate') {
            Integer pageNum = (req.pageNumber != null && req.pageNumber > 0) ? req.pageNumber : 1;
            offsetVal = (pageNum - 1) * limitVal;
            if (offsetVal > 2000) {
                offsetVal = 2000;
            }
            dataQuery = 'SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c, ' +
                        'Policy_Decision__c, Recommendation_Status__c, Status__c, ' +
                        'Approval_Status__c, Execution_Status__c, Execution_Action__c, ' +
                        'Execution_Result__c, Executed_At__c, Runbook_Key__c, ' +
                        'Created_Case__c, Created_Case__r.CaseNumber, CreatedDate, ' +
                        'Environment__c, AI_Confidence__c, AI_Reasoning_Status__c ' +
                        'FROM Sentinel_Incident__c ' +
                        dataWhereClause + ' ' +
                        'ORDER BY ' + sortByField + ' ' + querySortDir + ', Id ' + querySortDir + ' ' +
                        'LIMIT :limitVal OFFSET :offsetVal';
        } else {
            dataQuery = 'SELECT Id, Name, Incident_Type__c, Risk_Level__c, Risk_Score__c, ' +
                        'Policy_Decision__c, Recommendation_Status__c, Status__c, ' +
                        'Approval_Status__c, Execution_Status__c, Execution_Action__c, ' +
                        'Execution_Result__c, Executed_At__c, Runbook_Key__c, ' +
                        'Created_Case__c, Created_Case__r.CaseNumber, CreatedDate, ' +
                        'Environment__c, AI_Confidence__c, AI_Reasoning_Status__c ' +
                        'FROM Sentinel_Incident__c ' +
                        dataWhereClause + ' ' +
                        'ORDER BY ' + sortByField + ' ' + querySortDir + ', Id ' + querySortDir + ' ' +
                        'LIMIT :limitVal';
        }
                           
        List<Sentinel_Incident__c> incidents = Database.query(dataQuery);
        
        // If it was a PREV query, reverse the list in-memory to restore the user's expected sorting
        if (req.direction == 'PREV' && isKeysetApplied && !incidents.isEmpty()) {
            List<Sentinel_Incident__c> reversed = new List<Sentinel_Incident__c>();
            for (Integer i = incidents.size() - 1; i >= 0; i--) {
                reversed.add(incidents[i]);
            }
            incidents = reversed;
        }
        
        List<IncidentRow> rows = toIncidentRows(incidents);
        
        KeysetPaginatedResult result = new KeysetPaginatedResult();
        result.records = rows;
        result.totalRecords = totalCount;
        result.hasMore = totalCount > limitVal;
        
        Integer returnPageNum = (req.pageNumber != null && req.pageNumber > 0) ? req.pageNumber : 1;
        result.pageNumber = returnPageNum;
        result.totalPages = (totalCount == 0) ? 0 : (Integer)Math.ceil((Double)totalCount / limitVal);
        
        if (!rows.isEmpty()) {
            result.previousCursorCreatedDate = String.valueOf(rows[0].createdDate.getTime());
            result.previousCursorId = rows[0].id;
            
            result.nextCursorCreatedDate = String.valueOf(rows[rows.size() - 1].createdDate.getTime());
            result.nextCursorId = rows[rows.size() - 1].id;
        }
        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static CostAnalyticsResult getCostSavingsAnalytics(String dateRange) {
        Decimal hourlyRate = SystemSettings.get('Engineering_Hourly_Rate', 80.0);
        Decimal manualHours = SystemSettings.get('Manual_Resolution_Hours', 2.0);
        Decimal baselineMttr = SystemSettings.get('Baseline_MTTR_Minutes', 240.0);
        Decimal costPerCase = SystemSettings.get('Cost_Per_Support_Case', 150.0);

        Datetime cutoff = getCutoff(dateRange);
        List<Sentinel_Incident__c> resolvedIncidents;
        if (cutoff == null) {
            resolvedIncidents = [
                SELECT CreatedDate, Executed_At__c, Created_Case__c
                FROM Sentinel_Incident__c
                WHERE Execution_Status__c = 'Executed'
            ];
        } else {
            resolvedIncidents = [
                SELECT CreatedDate, Executed_At__c, Created_Case__c
                FROM Sentinel_Incident__c
                WHERE Execution_Status__c = 'Executed' AND CreatedDate >= :cutoff
            ];
        }

        Integer successfulRecoveries = resolvedIncidents.size();
        Decimal hoursSaved = successfulRecoveries * manualHours;
        
        Integer casesAvoidedCount = 0;
        Decimal totalResolutionTimeMinutes = 0;
        Integer resolutionTimeCount = 0;
        
        for (Sentinel_Incident__c inc : resolvedIncidents) {
            if (inc.Created_Case__c == null) {
                casesAvoidedCount++;
            }
            if (inc.Executed_At__c != null && inc.CreatedDate != null) {
                Long diffMs = inc.Executed_At__c.getTime() - inc.CreatedDate.getTime();
                Decimal diffMinutes = Decimal.valueOf(diffMs) / 60000.0;
                if (diffMinutes >= 0) {
                    totalResolutionTimeMinutes += diffMinutes;
                    resolutionTimeCount++;
                }
            }
        }

        Decimal engineeringSavings = hoursSaved * hourlyRate;
        Decimal caseSavings = casesAvoidedCount * costPerCase;
        Decimal estimatedCostSavingsVal = engineeringSavings + caseSavings;

        Decimal actualAvgMttr = 0;
        if (resolutionTimeCount > 0) {
            actualAvgMttr = totalResolutionTimeMinutes / resolutionTimeCount;
        }

        Decimal mttrImprovement = 0;
        if (baselineMttr > 0) {
            mttrImprovement = ((baselineMttr - actualAvgMttr) / baselineMttr) * 100;
        }

        CostAnalyticsResult result = new CostAnalyticsResult();
        result.successfulRecoveries = successfulRecoveries;
        result.hoursSaved = hoursSaved.setScale(2, System.RoundingMode.HALF_UP);
        result.casesAvoided = casesAvoidedCount;
        result.estimatedCostSavings = estimatedCostSavingsVal.setScale(2, System.RoundingMode.HALF_UP);
        result.automatedMttrMinutes = actualAvgMttr.setScale(2, System.RoundingMode.HALF_UP);
        result.mttrImprovementPercent = mttrImprovement.setScale(2, System.RoundingMode.HALF_UP);
        return result;
    }

    private static Object parseCursorValue(String sortBy, String valueStr) {
        if (String.isBlank(valueStr)) {
            return null;
        }
        if (sortBy == 'CreatedDate') {
            try {
                if (valueStr.contains('T') || valueStr.contains('-')) {
                    String jsonStr = '"' + valueStr + '"';
                    return (Datetime)JSON.deserialize(jsonStr, Datetime.class);
                } else {
                    return Datetime.newInstance(Long.valueOf(valueStr));
                }
            } catch (Exception e) {
                try {
                    return Datetime.valueOf(valueStr.replace('T', ' ').replace('Z', ''));
                } catch (Exception ex) {
                    return null;
                }
            }
        }
        return valueStr;
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
            
            // Milestone 43F: Escalation logic
            row.escalationNeeded = false;
            if (incident.Status__c == 'Approval Required' && incident.Approval_Status__c != 'Approved') {
                if (incident.CreatedDate != null && incident.CreatedDate.addHours(ESCALATION_THRESHOLD_HOURS) < System.now()) {
                    row.escalationNeeded = true;
                    row.escalationReason = 'Pending approval > ' + ESCALATION_THRESHOLD_HOURS + ' hours';
                }
            }
            
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
        @AuraEnabled public Sentinel_Incident__c latestCriticalIncident;
    }

    public class AiSignal {
        @AuraEnabled public String aiStatus;
        @AuraEnabled public Integer confidenceScore;
    }

    public class PaginatedRequest {
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public String sortBy { get; set; }
        @AuraEnabled public String sortDirection { get; set; }
        @AuraEnabled public String dateRange { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String environment { get; set; }
        @AuraEnabled public String incidentType { get; set; }
        @AuraEnabled public String aiStatus { get; set; }
    }

    public class PaginatedResult {
        @AuraEnabled public List<IncidentRow> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
    }

    public class FilterWrapper {
        @AuraEnabled public String dateRange { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String environment { get; set; }
        @AuraEnabled public String incidentType { get; set; }
        @AuraEnabled public String aiStatus { get; set; }
    }

    public class KeysetPaginatedRequest {
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public String sortBy { get; set; }
        @AuraEnabled public String sortDirection { get; set; }
        @AuraEnabled public FilterWrapper filters { get; set; }
        @AuraEnabled public String nextCursorCreatedDate { get; set; }
        @AuraEnabled public String nextCursorId { get; set; }
        @AuraEnabled public String previousCursorCreatedDate { get; set; }
        @AuraEnabled public String previousCursorId { get; set; }
        @AuraEnabled public String direction { get; set; } // 'NEXT' or 'PREV'
    }

    public class KeysetPaginatedResult {
        @AuraEnabled public List<IncidentRow> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Boolean hasMore { get; set; }
        @AuraEnabled public String nextCursorCreatedDate { get; set; }
        @AuraEnabled public String nextCursorId { get; set; }
        @AuraEnabled public String previousCursorCreatedDate { get; set; }
        @AuraEnabled public String previousCursorId { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
    }

    public class CostAnalyticsResult {
        @AuraEnabled public Integer successfulRecoveries { get; set; }
        @AuraEnabled public Decimal hoursSaved { get; set; }
        @AuraEnabled public Integer casesAvoided { get; set; }
        @AuraEnabled public Decimal estimatedCostSavings { get; set; }
        @AuraEnabled public Decimal automatedMttrMinutes { get; set; }
        @AuraEnabled public Decimal mttrImprovementPercent { get; set; }
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
        @AuraEnabled public Boolean escalationNeeded;
        @AuraEnabled public String escalationReason;
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

    public class ReplayExportData {
        @AuraEnabled public String incidentName;
        @AuraEnabled public String incidentType;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public String policyDecision;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String executionStatus;
        @AuraEnabled public List<ReplayExportEvent> events;
    }

    public class ReplayExportEvent {
        @AuraEnabled public String eventName;
        @AuraEnabled public Datetime eventTime;
        @AuraEnabled public String eventDetails;
        @AuraEnabled public String actor;
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
                SELECT Id, Name, Status__c, Approval_Status__c,
                       Incident_Type__c, Risk_Level__c, Execution_Status__c,
                       AI_Reasoning_Status__c, AI_Confidence__c, Environment__c
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
            SentinelFlowEventPublisher.publish(
                'APPROVED', inc,
                'ZentomDashboardController.approveWorkflow',
                'Incident ' + inc.Name + ' approved by ' + approvedBy
            );
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
                SELECT Id, Name, Status__c, Approval_Status__c,
                       Incident_Type__c, Risk_Level__c, Execution_Status__c,
                       AI_Reasoning_Status__c, AI_Confidence__c, Environment__c
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
            SentinelFlowEventPublisher.publish(
                'REJECTED', inc,
                'ZentomDashboardController.rejectWorkflow',
                'Incident ' + inc.Name + ' rejected. Reason: ' + reason
            );
            return '{"success": true, "incidentId": "' + inc.Name + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }


    @AuraEnabled(cacheable=true)
    public static ReplayExportData getReplayExportData(Id incidentId) {
        Sentinel_Incident__c inc = [
            SELECT Name, Incident_Type__c, Risk_Level__c, Policy_Decision__c,
                   Approval_Status__c, Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incidentId
        ];
        
        ReplayExportData data = new ReplayExportData();
        data.incidentName = inc.Name;
        data.incidentType = inc.Incident_Type__c;
        data.riskLevel = inc.Risk_Level__c;
        data.policyDecision = inc.Policy_Decision__c;
        data.approvalStatus = inc.Approval_Status__c;
        data.executionStatus = inc.Execution_Status__c;
        data.events = new List<ReplayExportEvent>();
        
        List<Sentinel_Audit_Log__c> logs = [
            SELECT Event_Type__c, CreatedDate, Decision__c, CreatedBy.Name
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incidentId
            ORDER BY CreatedDate ASC
        ];
        
        for (Sentinel_Audit_Log__c log : logs) {
            ReplayExportEvent ev = new ReplayExportEvent();
            ev.eventName = log.Event_Type__c;
            ev.eventTime = log.CreatedDate;
            ev.eventDetails = log.Decision__c;
            ev.actor = log.CreatedBy.Name;
            data.events.add(ev);
        }
        
        return data;
    }

    // ─── UTILITIES ───────────────────────────────────────────────────────────

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
                SELECT Id, Name, Status__c, Approval_Status__c, Execution_Status__c, Runbook_Key__c,
                       Incident_Type__c, Risk_Level__c, AI_Reasoning_Status__c,
                       AI_Confidence__c, Environment__c
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
            SentinelFlowEventPublisher.publish(
                'ACTION_EXECUTED', inc,
                'ZentomDashboardController.executeApprovedAction',
                'Runbook executed for incident ' + inc.Name + ' by ' + executedBy
            );
            SentinelFlowEventPublisher.publish(
                'CASE_CREATED', inc,
                'ZentomDashboardController.executeApprovedAction',
                'Case ' + createdCase.CaseNumber + ' created for incident ' + inc.Name
            );
            return '{"success": true, "incidentId": "' + inc.Name + '", "caseNumber": "' + createdCase.CaseNumber + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
}