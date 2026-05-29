@IsTest
private class ZentomDashboardControllerTest {
    @IsTest
    static void getDashboardData_returnsSummaryAndRows() {
        Case createdCase = new Case(
            Subject = 'SentinelFlow execution case',
            Status = 'New',
            Origin = 'Web'
        );
        insert createdCase;

        Sentinel_Incident__c pending = createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        Sentinel_Incident__c executed = createIncident(
            'CRITICAL',
            'Approved',
            'Executed',
            'Action Created',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        executed.Created_Case__c = createdCase.Id;
        Sentinel_Incident__c rejected = createIncident(
            'MEDIUM',
            'Rejected',
            'Skipped',
            'Closed',
            'GENERAL_INCIDENT_REVIEW'
        );

        insert new List<Sentinel_Incident__c>{
            pending,
            executed,
            rejected
        };

        insert new List<Sentinel_Audit_Log__c>{
            new Sentinel_Audit_Log__c(
                Incident__c = pending.Id,
                Event_Type__c = 'AI_RECOMMENDATION',
                Decision__c = 'Pending Approval',
                Trace_Id__c = 'trace-pending'
            ),
            new Sentinel_Audit_Log__c(
                Incident__c = executed.Id,
                Event_Type__c = 'EXECUTION',
                Decision__c = 'Executed',
                Trace_Id__c = 'trace-executed'
            )
        };

        Test.startTest();
        ZentomDashboardController.DashboardData data =
            ZentomDashboardController.getDashboardData('ALL');
        Test.stopTest();

        System.assertEquals(3, data.summary.totalIncidents);
        System.assertEquals(2, data.summary.criticalIncidents);
        System.assertEquals(1, data.summary.pendingApprovals);
        System.assertEquals(1, data.summary.executedActions);
        System.assertEquals(1, data.summary.rejectedRecommendations);
        System.assertEquals(2, data.summary.recentReplayEvents);
        System.assertEquals(1, data.summary.recentCasesCreated);
        System.assertEquals(1, data.summary.approvalRequired);
        System.assertEquals('FLOW_FAILURE_BASIC_RECOVERY', data.summary.topRunbook);
        System.assertEquals(77, data.summary.orgHealthScore);
        System.assertEquals('Stable', data.summary.orgHealthStatus);
        System.assert(data.summary.orgHealthReason.contains('1 critical open incident'));
        System.assert(data.summary.orgHealthReason.contains('1 pending approval'));
        System.assert(data.summary.orgHealthReason.contains('1 rejected recommendation'));
        System.assertEquals(3, data.recentIncidents.size());
        System.assertEquals(1, data.pendingApprovals.size());
        System.assertEquals(1, data.recentExecutions.size());
        System.assertEquals(createdCase.Id, data.recentExecutions[0].createdCaseId);
        System.assertEquals(1, data.recentCasesCreated.size());
        System.assert(!data.riskDistribution.isEmpty(), 'Risk distribution should be returned.');
        System.assertNotEquals(null, data.latestAiSignal, 'latestAiSignal should not be null');
        System.assertEquals('ACTIVE', data.latestAiSignal.aiStatus);
        System.assertEquals(87, data.latestAiSignal.confidenceScore);

        ZentomDashboardController.DashboardData todayData =
            ZentomDashboardController.getDashboardData('TODAY');
        System.assertEquals(3, todayData.summary.totalIncidents);

        ZentomDashboardController.DashboardSummary recentSummary =
            ZentomDashboardController.getDashboardSummary('LAST_7_DAYS');
        System.assertEquals(3, recentSummary.totalIncidents);

        System.assertEquals(3, ZentomDashboardController.getRecentIncidents('TODAY').size());
        System.assertEquals(1, ZentomDashboardController.getPendingApprovalRows('TODAY').size());
        System.assertEquals(1, ZentomDashboardController.getRecentExecutions('TODAY').size());
        System.assertEquals(2, ZentomDashboardController.getRecentReplayEvents('TODAY').size());
        System.assertEquals(1, ZentomDashboardController.getRecentCasesCreated('TODAY').size());
    }

    @IsTest
    static void orgHealthScore_noIncidentsIsHealthy() {
        Test.startTest();
        ZentomDashboardController.DashboardSummary summary =
            ZentomDashboardController.getDashboardSummary('ALL');
        Test.stopTest();

        System.assertEquals(100, summary.orgHealthScore);
        System.assertEquals('Healthy', summary.orgHealthStatus);
        System.assertEquals(
            'No active incidents are reducing the org health score.',
            summary.orgHealthReason
        );
    }

    @IsTest
    static void orgHealthScore_criticalOpenIncidentReducesScore() {
        insert createIncident(
            'CRITICAL',
            'Approved',
            'Not Started',
            'Approved',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );

        ZentomDashboardController.DashboardSummary summary =
            ZentomDashboardController.getDashboardSummary('ALL');

        System.assertEquals(90, summary.orgHealthScore);
        System.assertEquals('Healthy', summary.orgHealthStatus);
        System.assert(summary.orgHealthReason.contains('1 critical open incident'));
    }

    @IsTest
    static void orgHealthScore_pendingApprovalReducesScore() {
        insert createIncident(
            'LOW',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );

        ZentomDashboardController.DashboardSummary summary =
            ZentomDashboardController.getDashboardSummary('ALL');

        System.assertEquals(92, summary.orgHealthScore);
        System.assertEquals('Healthy', summary.orgHealthStatus);
        System.assert(summary.orgHealthReason.contains('1 pending approval'));
    }

    @IsTest
    static void orgHealthScore_failedExecutionReducesScore() {
        insert createIncident(
            'LOW',
            'Approved',
            'Failed',
            'Approved',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );

        ZentomDashboardController.DashboardSummary summary =
            ZentomDashboardController.getDashboardSummary('ALL');

        System.assertEquals(88, summary.orgHealthScore);
        System.assertEquals('Stable', summary.orgHealthStatus);
        System.assert(summary.orgHealthReason.contains('1 failed execution'));
    }

    @IsTest
    static void orgHealthScore_neverFallsBelowZero() {
        List<Sentinel_Incident__c> incidents = new List<Sentinel_Incident__c>();
        for (Integer index = 0; index < 11; index++) {
            incidents.add(createIncident(
                'CRITICAL',
                'Approved',
                'Not Started',
                'Approved',
                'FLOW_FAILURE_BASIC_RECOVERY'
            ));
        }
        insert incidents;

        ZentomDashboardController.DashboardSummary summary =
            ZentomDashboardController.getDashboardSummary('ALL');

        System.assertEquals(0, summary.orgHealthScore);
        System.assertEquals('Critical', summary.orgHealthStatus);
    }

    @IsTest
    static void getPendingApprovals_returnsRows() {
        insert createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );

        Test.startTest();
        List<ZentomDashboardController.ZentomApprovalRow> rows = ZentomDashboardController.getPendingApprovals();
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Should return 1 pending approval');
        System.assertNotEquals(null, rows[0].id);
        System.assertEquals(87, rows[0].confidence); // populated by createIncident
    }

    @IsTest
    static void approveWorkflow_updatesIncident() {
        Sentinel_Incident__c inc = createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert inc;

        Test.startTest();
        String result = ZentomDashboardController.approveWorkflow(inc.Id, 'Test User');
        Test.stopTest();

        System.assert(result.contains('"success": true'), 'Result should be successful: ' + result);

        Sentinel_Incident__c updatedInc = [SELECT Approval_Status__c, Status__c, Execution_Status__c FROM Sentinel_Incident__c WHERE Id = :inc.Id];
        System.assertEquals('Approved', updatedInc.Approval_Status__c);
        System.assertEquals('Approved', updatedInc.Status__c);
        System.assertEquals('Ready for Execution', updatedInc.Execution_Status__c);

        List<Zentom_Policy_Decision__c> decisions = [SELECT Decision__c, Reason__c, Action_Type__c FROM Zentom_Policy_Decision__c WHERE Incident__c = :inc.Id];
        System.assertEquals(1, decisions.size(), 'Should insert 1 decision record');
        System.assertEquals('Approved', decisions[0].Decision__c);
        System.assertEquals('Approved by Test User', decisions[0].Reason__c);
        System.assertEquals('Runbook Execution', decisions[0].Action_Type__c);
        
        // Test Already Processed
        String duplicateResult = ZentomDashboardController.approveWorkflow(inc.Id, 'Test User');
        System.assert(duplicateResult.contains('already processed'));
    }

    @IsTest
    static void rejectWorkflow_updatesIncident() {
        Sentinel_Incident__c inc = createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert inc;

        Test.startTest();
        String result = ZentomDashboardController.rejectWorkflow(inc.Id, 'Too risky');
        Test.stopTest();

        System.assert(result.contains('"success": true'), 'Result should be successful: ' + result);

        Sentinel_Incident__c updatedInc = [SELECT Approval_Status__c, Status__c, Execution_Status__c FROM Sentinel_Incident__c WHERE Id = :inc.Id];
        System.assertEquals('Rejected', updatedInc.Approval_Status__c);
        System.assertEquals('Analyzed', updatedInc.Status__c);
        System.assertEquals('Not Started', updatedInc.Execution_Status__c);

        List<Zentom_Policy_Decision__c> decisions = [SELECT Decision__c, Reason__c, Action_Type__c FROM Zentom_Policy_Decision__c WHERE Incident__c = :inc.Id];
        System.assertEquals(1, decisions.size(), 'Should insert 1 decision record');
        System.assertEquals('Rejected', decisions[0].Decision__c);
        System.assertEquals('Too risky', decisions[0].Reason__c);
        System.assertEquals('Runbook Execution Cancelled', decisions[0].Action_Type__c);
    }

    @IsTest
    static void getPendingActions_returnsRows() {
        insert createIncident(
            'CRITICAL',
            'Approved',
            'Ready for Execution',
            'Approved',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );

        Test.startTest();
        List<ZentomDashboardController.ZentomActionRow> rows = ZentomDashboardController.getPendingActions();
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Should return 1 pending action');
        System.assertNotEquals(null, rows[0].id);
        System.assertEquals(87, rows[0].confidence); // populated by createIncident
    }

    @IsTest
    static void executeApprovedAction_createsCaseAndUpdateIncident() {
        Sentinel_Incident__c inc = createIncident(
            'CRITICAL',
            'Approved',
            'Ready for Execution',
            'Approved',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert inc;

        Test.startTest();
        String result = ZentomDashboardController.executeApprovedAction(inc.Id, 'Test Executor');
        Test.stopTest();

        System.assert(result.contains('"success": true'), 'Result should be successful: ' + result);
        System.assert(result.contains('"caseNumber"'), 'Result should contain a caseNumber: ' + result);

        Sentinel_Incident__c updatedInc = [SELECT Execution_Status__c, Status__c, Created_Case__c FROM Sentinel_Incident__c WHERE Id = :inc.Id];
        System.assertEquals('Executed', updatedInc.Execution_Status__c);
        System.assertEquals('Closed', updatedInc.Status__c);
        System.assertNotEquals(null, updatedInc.Created_Case__c);

        Case createdCase = [SELECT Subject, Origin FROM Case WHERE Id = :updatedInc.Created_Case__c];
        System.assert(createdCase.Subject.contains('SentinelFlow Execution'));

        List<Zentom_Policy_Decision__c> decisions = [SELECT Decision__c, Reason__c FROM Zentom_Policy_Decision__c WHERE Incident__c = :inc.Id];
        System.assertEquals(1, decisions.size(), 'Should insert 1 decision record for execution');
        System.assertEquals('Executed', decisions[0].Decision__c);
    }

    @IsTest
    static void executeApprovedAction_rejectsUnapprovedOrAlreadyExecuted() {
        Sentinel_Incident__c unapproved = createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        Sentinel_Incident__c executed = createIncident(
            'CRITICAL',
            'Approved',
            'Executed',
            'Closed',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert new List<Sentinel_Incident__c>{ unapproved, executed };

        Test.startTest();
        String unapprovedResult = ZentomDashboardController.executeApprovedAction(unapproved.Id, 'Test Executor');
        String executedResult = ZentomDashboardController.executeApprovedAction(executed.Id, 'Test Executor');
        Test.stopTest();

        System.assert(unapprovedResult.contains('error'), 'Should return error for unapproved incident');
        System.assert(unapprovedResult.contains('must be approved'));
        
        System.assert(executedResult.contains('error'), 'Should return error for already executed incident');
        System.assert(executedResult.contains('already been executed'));
    }

    @IsTest
    static void getReplayExportData_returnsValidExportData() {
        Sentinel_Incident__c inc = createIncident(
            'CRITICAL',
            'Approved',
            'Ready for Execution',
            'Approved',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert inc;

        Sentinel_Audit_Log__c log1 = new Sentinel_Audit_Log__c(
            Incident__c = inc.Id,
            Event_Type__c = 'DETECTION',
            Decision__c = 'Anomaly detected'
        );
        Sentinel_Audit_Log__c log2 = new Sentinel_Audit_Log__c(
            Incident__c = inc.Id,
            Event_Type__c = 'POLICY_EVALUATION',
            Decision__c = 'Human approval required'
        );
        insert new List<Sentinel_Audit_Log__c>{ log1, log2 };

        Test.startTest();
        ZentomDashboardController.ReplayExportData data = ZentomDashboardController.getReplayExportData(inc.Id);
        Test.stopTest();

        System.assertNotEquals(null, data, 'Export data should not be null');
        System.assertEquals(inc.Incident_Type__c, data.incidentType, 'Incident type should match');
        System.assertEquals('CRITICAL', data.riskLevel, 'Risk level should match');
        System.assertEquals(2, data.events.size(), 'Should return 2 events');
        System.assertEquals('DETECTION', data.events[0].eventName, 'First event should be DETECTION');
    }

    @IsTest
    static void getDashboardData_flagsOverdueApprovals() {
        Sentinel_Incident__c inc = createIncident(
            'CRITICAL',
            'Pending Approval',
            'Not Started',
            'Approval Required',
            'FLOW_FAILURE_BASIC_RECOVERY'
        );
        insert inc;
        
        Test.setCreatedDate(inc.Id, System.now().addHours(-5));

        Test.startTest();
        ZentomDashboardController.DashboardData data = ZentomDashboardController.getDashboardData('LAST_7_DAYS');
        Test.stopTest();

        System.assertEquals(1, data.pendingApprovals.size(), 'Should have 1 pending approval');
        System.assertEquals(true, data.pendingApprovals[0].escalationNeeded, 'Should be flagged for escalation');
        System.assert(data.pendingApprovals[0].escalationReason.contains('Pending approval'), 'Should have escalation reason');
    }

    private static Sentinel_Incident__c createIncident(
        String riskLevel,
        String approvalStatus,
        String executionStatus,
        String status,
        String runbookKey
    ) {
        return new Sentinel_Incident__c(
            Incident_Type__c = 'FLOW_FAILURE',
            Source__c = 'Salesforce Flow',
            Environment__c = 'production',
            Error_Message__c = 'Flow failed due to missing Account Owner',
            Risk_Score__c = riskLevel == 'CRITICAL' ? 95 : 45,
            Risk_Level__c = riskLevel,
            Policy_Decision__c = 'HUMAN_APPROVAL_REQUIRED',
            Policy_Reason__c = 'Production environment requires human approval',
            Status__c = status,
            AI_Summary__c = 'Salesforce Flow failed because Account Owner was missing.',
            Root_Cause__c = 'Required owner lookup was null during Flow execution.',
            Recommended_Action__c = 'Create an admin case and review Flow input validation.',
            AI_Confidence__c = 87,
            Runbook_Key__c = runbookKey,
            Runbook_Steps__c = '1. Review the failed Flow interview.',
            AI_Reasoning_Status__c = 'ACTIVE',
            AI_Explanation__c = 'This is a test AI explanation.',
            Orchestration_Mode__c = 'HYBRID',
            Memory_Used__c = true,
            Recommendation_Status__c = approvalStatus == 'Rejected'
                ? 'Rejected'
                : (approvalStatus == 'Approved' ? 'Approved' : 'Generated'),
            Approval_Status__c = approvalStatus,
            Execution_Status__c = executionStatus,
            Execution_Action__c = executionStatus == 'Executed' ? 'CREATE_CASE' : null,
            Execution_Result__c = executionStatus == 'Executed' ? 'Case created' : null
        );
    }

    @IsTest
    static void testGetPaginatedIncidents_AllScenarios() {
        // Insert a variety of incidents for pagination, sorting and filtering checks
        List<Sentinel_Incident__c> incidents = new List<Sentinel_Incident__c>();
        
        // Incident 1: Critical, production, Flow Failure, High AI Confidence
        Sentinel_Incident__c inc1 = createIncident('CRITICAL', 'Pending Approval', 'Not Started', 'Approval Required', 'RUNBOOK_A');
        inc1.Environment__c = 'production';
        inc1.Incident_Type__c = 'FLOW_FAILURE';
        inc1.AI_Confidence__c = 95;
        inc1.AI_Reasoning_Status__c = 'ACTIVE';
        incidents.add(inc1);
        
        // Incident 2: Low, sandbox, Integration Error, Low AI Confidence
        Sentinel_Incident__c inc2 = createIncident('LOW', 'Approved', 'Executed', 'Closed', 'RUNBOOK_B');
        inc2.Environment__c = 'sandbox';
        inc2.Incident_Type__c = 'INTEGRATION_ERROR';
        inc2.AI_Confidence__c = 45;
        inc2.AI_Reasoning_Status__c = 'ACTIVE';
        incidents.add(inc2);
        
        // Incident 3: High, production, Apex Exception, High AI Confidence
        Sentinel_Incident__c inc3 = createIncident('HIGH', 'Approved', 'Executed', 'Closed', 'RUNBOOK_C');
        inc3.Environment__c = 'production';
        inc3.Incident_Type__c = 'APEX_EXCEPTION';
        inc3.AI_Confidence__c = 85;
        inc3.AI_Reasoning_Status__c = 'ACTIVE';
        incidents.add(inc3);

        insert incidents;
        
        // Verify default request
        ZentomDashboardController.PaginatedRequest reqDefault = new ZentomDashboardController.PaginatedRequest();
        reqDefault.pageNumber = 1;
        reqDefault.pageSize = 25;
        
        Test.startTest();
        ZentomDashboardController.PaginatedResult resultDefault = ZentomDashboardController.getPaginatedIncidents(reqDefault);
        
        // Verify sorting default and results
        System.assertEquals(3, resultDefault.totalRecords, 'Total records should be 3');
        System.assertEquals(3, resultDefault.records.size(), 'Records list size should be 3');
        System.assertEquals(1, resultDefault.pageNumber, 'Page number should be 1');
        System.assertEquals(1, resultDefault.totalPages, 'Total pages should be 1');
        
        // Verify filtering by Risk Level
        ZentomDashboardController.PaginatedRequest reqFilterRisk = new ZentomDashboardController.PaginatedRequest();
        reqFilterRisk.riskLevel = 'CRITICAL';
        ZentomDashboardController.PaginatedResult resultRisk = ZentomDashboardController.getPaginatedIncidents(reqFilterRisk);
        System.assertEquals(1, resultRisk.records.size(), 'Should return 1 critical incident');
        System.assertEquals('CRITICAL', resultRisk.records[0].riskLevel, 'Risk level should match');
        
        // Verify filtering by Environment
        ZentomDashboardController.PaginatedRequest reqFilterEnv = new ZentomDashboardController.PaginatedRequest();
        reqFilterEnv.environment = 'sandbox';
        ZentomDashboardController.PaginatedResult resultEnv = ZentomDashboardController.getPaginatedIncidents(reqFilterEnv);
        System.assertEquals(1, resultEnv.records.size(), 'Should return 1 sandbox incident');
        System.assertEquals('sandbox', resultEnv.records[0].environment, 'Environment should match');
        
        // Verify filtering by Status
        ZentomDashboardController.PaginatedRequest reqFilterStatus = new ZentomDashboardController.PaginatedRequest();
        reqFilterStatus.status = 'Closed';
        ZentomDashboardController.PaginatedResult resultStatus = ZentomDashboardController.getPaginatedIncidents(reqFilterStatus);
        System.assertEquals(2, resultStatus.records.size(), 'Should return 2 closed incidents');
        
        // Verify filtering by Incident Type
        ZentomDashboardController.PaginatedRequest reqFilterType = new ZentomDashboardController.PaginatedRequest();
        reqFilterType.incidentType = 'APEX_EXCEPTION';
        ZentomDashboardController.PaginatedResult resultType = ZentomDashboardController.getPaginatedIncidents(reqFilterType);
        System.assertEquals(1, resultType.records.size(), 'Should return 1 apex exception incident');
        
        // Verify filtering by AI Status - HIGH_CONFIDENCE (>80)
        ZentomDashboardController.PaginatedRequest reqFilterAiHigh = new ZentomDashboardController.PaginatedRequest();
        reqFilterAiHigh.aiStatus = 'HIGH_CONFIDENCE';
        ZentomDashboardController.PaginatedResult resultAiHigh = ZentomDashboardController.getPaginatedIncidents(reqFilterAiHigh);
        System.assertEquals(2, resultAiHigh.records.size(), 'Should return 2 high confidence incidents (95, 85)');
        
        // Verify filtering by AI Status - REVIEW_NEEDED (<=80)
        ZentomDashboardController.PaginatedRequest reqFilterAiReview = new ZentomDashboardController.PaginatedRequest();
        reqFilterAiReview.aiStatus = 'REVIEW_NEEDED';
        ZentomDashboardController.PaginatedResult resultAiReview = ZentomDashboardController.getPaginatedIncidents(reqFilterAiReview);
        System.assertEquals(1, resultAiReview.records.size(), 'Should return 1 review needed incident (45)');

        // Verify filtering by AI Status - ACTIVE
        ZentomDashboardController.PaginatedRequest reqFilterAiActive = new ZentomDashboardController.PaginatedRequest();
        reqFilterAiActive.aiStatus = 'ACTIVE';
        ZentomDashboardController.PaginatedResult resultAiActive = ZentomDashboardController.getPaginatedIncidents(reqFilterAiActive);
        System.assertEquals(3, resultAiActive.records.size(), 'Should return 3 active reasoning incidents');
        
        // Verify Sorting - whitelisted sortBy
        ZentomDashboardController.PaginatedRequest reqSortName = new ZentomDashboardController.PaginatedRequest();
        reqSortName.sortBy = 'Name';
        reqSortName.sortDirection = 'ASC';
        ZentomDashboardController.PaginatedResult resultSortName = ZentomDashboardController.getPaginatedIncidents(reqSortName);
        System.assertNotEquals(null, resultSortName.records, 'Sorted records list should not be null');
        
        // Verify Sorting - non-whitelisted sortBy fallback to CreatedDate DESC
        ZentomDashboardController.PaginatedRequest reqSortInvalid = new ZentomDashboardController.PaginatedRequest();
        reqSortInvalid.sortBy = 'Non_Existing_Field__c';
        reqSortInvalid.sortDirection = 'INVALID_DIRECTION';
        ZentomDashboardController.PaginatedResult resultSortInvalid = ZentomDashboardController.getPaginatedIncidents(reqSortInvalid);
        System.assertNotEquals(null, resultSortInvalid.records, 'Invalid sort parameters should fallback gracefully and not throw exception');
        
        // Verify dateRange parameter
        ZentomDashboardController.PaginatedRequest reqDateToday = new ZentomDashboardController.PaginatedRequest();
        reqDateToday.dateRange = 'TODAY';
        ZentomDashboardController.PaginatedResult resultDateToday = ZentomDashboardController.getPaginatedIncidents(reqDateToday);
        System.assertEquals(3, resultDateToday.records.size(), 'Should return all 3 created today');
        
        // Verify Null Request handling
        ZentomDashboardController.PaginatedResult resultNull = ZentomDashboardController.getPaginatedIncidents(null);
        System.assertNotEquals(null, resultNull, 'Null request should return empty result wrapper');
        
        // Verify Offset limit cap safety (offsetVal > 2000)
        ZentomDashboardController.PaginatedRequest reqOffsetOver = new ZentomDashboardController.PaginatedRequest();
        reqOffsetOver.pageNumber = 100; // offset = (100-1) * 25 = 2475 > 2000
        reqOffsetOver.pageSize = 25;
        ZentomDashboardController.PaginatedResult resultOffsetOver = ZentomDashboardController.getPaginatedIncidents(reqOffsetOver);
        System.assertEquals(100, resultOffsetOver.pageNumber, 'Page number should match requested page');
        
        Test.stopTest();
    }
}