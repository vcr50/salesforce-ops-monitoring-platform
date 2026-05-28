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
}