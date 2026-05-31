@IsTest
private class ZentomApprovalControllerTest {
    @IsTest
    static void approveIncident_updatesIncidentAndCreatesAuditLog() {
        Sentinel_Incident__c incident = createIncident();

        Test.startTest();
        ZentomApprovalController.ApprovalContext result =
            ZentomApprovalController.approveIncident(incident.Id);
        Test.stopTest();

        Sentinel_Incident__c approved = [
            SELECT Status__c, Approval_Status__c, Recommendation_Status__c,
                Approved_By__c, Approved_At__c, Rejection_Reason__c, Next_Action__c,
                Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Approved', approved.Status__c);
        System.assertEquals('Approved', approved.Approval_Status__c);
        System.assertEquals('Approved', approved.Recommendation_Status__c);
        System.assertEquals(UserInfo.getUserId(), approved.Approved_By__c);
        System.assertNotEquals(null, approved.Approved_At__c);
        System.assertEquals(null, approved.Rejection_Reason__c);
        System.assertEquals('Ready for Execution', approved.Execution_Status__c);
        System.assertEquals(false, result.canApprove);
        System.assertEquals(true, result.canExecute);

        ZentomExecutionController.ExecutionResult executionResult =
            ZentomExecutionController.executeApprovedAction(incident.Id);
        System.assertNotEquals(null, executionResult.caseId);
        System.assertEquals('Executed', executionResult.executionStatus);

        Boolean duplicateBlocked = false;
        try {
            ZentomExecutionController.executeApprovedAction(incident.Id);
        } catch (AuraHandledException e) {
            duplicateBlocked = true;
        }
        System.assert(duplicateBlocked, 'Already executed incidents should be blocked.');

        Boolean taskBlocked = false;
        try {
            ZentomExecutionController.createTaskFromIncident(incident.Id);
        } catch (AuraHandledException e) {
            taskBlocked = true;
        }
        System.assert(taskBlocked, 'Task execution is outside the MVP path.');

        Boolean lowConfidenceBlocked = false;
        try {
            ZentomExecutionController.executeAction(
                incident.Id,
                'CREATE_CASE',
                60,
                'AUTONOMOUS_EXECUTION'
            );
        } catch (AuraHandledException e) {
            lowConfidenceBlocked = true;
        }
        System.assert(lowConfidenceBlocked, 'Low confidence autonomous execution should be blocked.');

        Boolean policyBlocked = false;
        try {
            ZentomExecutionController.executeAction(
                incident.Id,
                'CREATE_CASE',
                95,
                'HUMAN_APPROVAL_REQUIRED'
            );
        } catch (AuraHandledException e) {
            policyBlocked = true;
        }
        System.assert(policyBlocked, 'Non-autonomous execution mode should be blocked.');

        Boolean experimentalBlocked = false;
        try {
            ZentomExecutionController.executeAction(
                incident.Id,
                'CREATE_CASE',
                95,
                'AUTONOMOUS_EXECUTION'
            );
        } catch (AuraHandledException e) {
            experimentalBlocked = true;
        }
        System.assert(experimentalBlocked, 'Agentforce execution should stay isolated from the MVP.');

        Sentinel_Audit_Log__c auditLog = [
            SELECT Event_Type__c, Decision__c, Incident__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
                AND Event_Type__c = 'HUMAN_APPROVED'
            LIMIT 1
        ];
        System.assertEquals('HUMAN_APPROVED', auditLog.Event_Type__c);
        System.assertEquals('APPROVED', auditLog.Decision__c);
    }

    @IsTest
    static void rejectIncident_updatesIncidentAndCreatesAuditLog() {
        Sentinel_Incident__c incident = createIncident();

        Test.startTest();
        ZentomApprovalController.ApprovalContext result =
            ZentomApprovalController.rejectIncident(incident.Id, 'Too risky for production.');
        Test.stopTest();

        Sentinel_Incident__c rejected = [
            SELECT Status__c, Approval_Status__c, Recommendation_Status__c,
                Rejection_Reason__c, Next_Action__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Closed', rejected.Status__c);
        System.assertEquals('Rejected', rejected.Approval_Status__c);
        System.assertEquals('Rejected', rejected.Recommendation_Status__c);
        System.assertEquals('Too risky for production.', rejected.Rejection_Reason__c);
        System.assertEquals(false, result.canReject);

        Sentinel_Audit_Log__c auditLog = [
            SELECT Event_Type__c, Decision__c, Request_Payload__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
            LIMIT 1
        ];
        System.assertEquals('HUMAN_REJECTED', auditLog.Event_Type__c);
        System.assertEquals('REJECTED', auditLog.Decision__c);
        System.assertEquals('Too risky for production.', auditLog.Request_Payload__c);
    }

    private static Sentinel_Incident__c createIncident() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'FLOW_FAILURE',
            Source__c = 'Salesforce Flow',
            Environment__c = 'production',
            Error_Message__c = 'Flow failed due to missing Account Owner',
            Risk_Score__c = 95,
            Risk_Level__c = 'CRITICAL',
            Policy_Decision__c = 'HUMAN_APPROVAL_REQUIRED',
            Policy_Reason__c = 'Production environment requires human approval',
            Status__c = 'Approval Required',
            AI_Summary__c = 'Salesforce Flow failed because Account Owner was missing.',
            Root_Cause__c = 'Required owner lookup was null during Flow execution.',
            Recommended_Action__c = 'Create an admin case and review Flow input validation.',
            AI_Confidence__c = 87,
            Runbook_Key__c = 'FLOW_FAILURE_BASIC_RECOVERY',
            Recommendation_Status__c = 'Generated',
            Approval_Status__c = 'Pending Approval',
            Execution_Status__c = 'Not Started',
            Next_Action__c = 'Awaiting human approval before execution'
        );
        insert incident;
        return incident;
    }
}