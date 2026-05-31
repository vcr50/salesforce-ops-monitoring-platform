/**
 * ZentomExecutionControllerTest
 * Validates the final governance gate and dispatch logic.
 */
@IsTest
private class ZentomExecutionControllerTest {
    @IsTest
    static void executeApprovedAction_createsCaseAndAuditLog() {
        Sentinel_Incident__c incident = createApprovedIncident();

        Test.startTest();
        ZentomExecutionController.ExecutionResult result =
            ZentomExecutionController.executeApprovedAction(incident.Id);
        Test.stopTest();

        Sentinel_Incident__c executed = [
            SELECT Status__c, Execution_Status__c, Execution_Action__c,
                Executed_At__c, Execution_Result__c, Created_Case__c,
                Next_Action__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Action Created', executed.Status__c);
        System.assertEquals('Executed', executed.Execution_Status__c);
        System.assertEquals('CREATE_CASE', executed.Execution_Action__c);
        System.assertNotEquals(null, executed.Executed_At__c);
        System.assertNotEquals(null, executed.Created_Case__c);
        System.assertEquals(executed.Created_Case__c, result.caseId);

        Case createdCase = [
            SELECT Subject, Priority, Origin, Description
            FROM Case
            WHERE Id = :executed.Created_Case__c
        ];
        System.assertEquals('[SentinelFlow] FLOW_FAILURE - CRITICAL', createdCase.Subject);
        System.assertEquals('High', createdCase.Priority);
        System.assertEquals('SentinelFlow', createdCase.Origin);
        System.assert(createdCase.Description.contains('Required owner lookup was null'));
        System.assert(createdCase.Description.contains('Runbook Steps:'));
        System.assert(createdCase.Description.contains('Review the failed Flow interview.'));

        Sentinel_Audit_Log__c auditLog = [
            SELECT Event_Type__c, Decision__c, Response_Payload__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
                AND Event_Type__c = 'RUNBOOK_ACTION_EXECUTED'
            LIMIT 1
        ];
        System.assertEquals('RUNBOOK_ACTION_EXECUTED', auditLog.Event_Type__c);
        System.assertEquals('CREATE_CASE', auditLog.Decision__c);
        System.assert(auditLog.Response_Payload__c.contains(String.valueOf(result.caseId)));

        Sentinel_Audit_Log__c caseAudit = [
            SELECT Event_Type__c, Decision__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
                AND Event_Type__c = 'CASE_CREATED'
            LIMIT 1
        ];
        System.assertEquals(String.valueOf(result.caseId), caseAudit.Decision__c);
    }

    @IsTest
    static void executeApprovedAction_blocksUnapprovedIncident() {
        Sentinel_Incident__c incident = createApprovedIncident();
        incident.Approval_Status__c = 'Pending Approval';
        update incident;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentomExecutionController.executeApprovedAction(incident.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Unapproved incident should not execute.');
    }

    @IsTest
    static void testExecuteAction_BlockedByLowConfidence() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentomExecutionController.executeAction(
                null,
                'Restart Service',
                60,
                'AUTONOMOUS_EXECUTION'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Low confidence should throw AuraHandledException');
    }

    @IsTest
    static void testExecuteAction_BlockedByPolicy() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentomExecutionController.executeAction(
                null,
                'Restart Service',
                95,
                'HUMAN_APPROVAL_REQUIRED'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Non-autonomous policy should throw AuraHandledException');
    }

    private static Sentinel_Incident__c createApprovedIncident() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'FLOW_FAILURE',
            Source__c = 'Salesforce Flow',
            Environment__c = 'production',
            Error_Message__c = 'Flow failed due to missing Account Owner',
            Risk_Score__c = 95,
            Risk_Level__c = 'CRITICAL',
            Policy_Decision__c = 'HUMAN_APPROVAL_REQUIRED',
            Policy_Reason__c = 'Production environment requires human approval',
            Status__c = 'Approved',
            AI_Summary__c = 'Salesforce Flow failed because Account Owner was missing.',
            Root_Cause__c = 'Required owner lookup was null during Flow execution.',
            Recommended_Action__c = 'Create an admin case and review Flow input validation.',
            AI_Confidence__c = 87,
            Runbook_Key__c = 'FLOW_FAILURE_BASIC_RECOVERY',
            Runbook_Title__c = 'Flow Failure Basic Recovery',
            Runbook_Description__c = 'Human-guided recovery checklist for failed Salesforce Flow interviews.',
            Runbook_Steps__c = '1. Review the failed Flow interview.\n' +
                '2. Check required fields such as Account Owner.\n' +
                '3. Validate recent Flow changes.\n' +
                '4. Confirm affected records and business impact.\n' +
                '5. Create admin case for remediation.',
            Recommendation_Status__c = 'Approved',
            Approval_Status__c = 'Approved',
            Execution_Status__c = 'Ready for Execution',
            Next_Action__c = 'Approval captured. Ready to create Salesforce Case.'
        );
        insert incident;
        return incident;
    }
}