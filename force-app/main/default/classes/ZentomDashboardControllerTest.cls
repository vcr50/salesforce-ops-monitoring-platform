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