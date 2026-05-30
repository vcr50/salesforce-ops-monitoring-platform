@IsTest
private class AutoHealExecutionServiceTest {

    @TestSetup
    static void setupTestData() {
        SystemSettings.clearOverrides();
    }

    @IsTest
    static void testExecuteAction_Success_CreateCase() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 35.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
        Test.stopTest();

        System.assert(result.success, 'Execution should be successful');
        System.assertEquals('CREATE_CASE', result.actionTaken);
        System.assertNotEquals(null, result.recordId, 'Record ID of Case should not be null');

        // Verify database updates
        Sentinel_Incident__c updatedInc = [
            SELECT Status__c, Execution_Status__c, Execution_Action__c, Executed_At__c, Created_Case__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Action Created', updatedInc.Status__c);
        System.assertEquals('Executed', updatedInc.Execution_Status__c);
        System.assertEquals('CREATE_CASE', updatedInc.Execution_Action__c);
        System.assertNotEquals(null, updatedInc.Executed_At__c);
        System.assertEquals(result.recordId, updatedInc.Created_Case__c);

        // Verify audit log
        List<Sentinel_Audit_Log__c> auditLogs = [
            SELECT Event_Type__c, Decision__c, Response_Payload__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
            ORDER BY CreatedDate DESC
        ];
        System.assert(!auditLogs.isEmpty(), 'Audit logs should be created');
        System.assertEquals('AUTO_HEAL_EXECUTED', auditLogs[0].Event_Type__c);
        System.assertEquals('SUCCESS', auditLogs[0].Decision__c);
    }

    @IsTest
    static void testExecuteAction_Success_CreateTask() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 10.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');
        Test.stopTest();

        System.assert(result.success, 'Execution should succeed');
        System.assertEquals('CREATE_TASK', result.actionTaken);
        System.assertNotEquals(null, result.recordId, 'Task ID should not be null');

        Sentinel_Incident__c updatedInc = [
            SELECT Status__c, Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Action Created', updatedInc.Status__c);
        System.assertEquals('Executed', updatedInc.Execution_Status__c);
    }

    @IsTest
    static void testExecuteAction_Success_OtherSafeActions() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 15.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        // SEND_NOTIFICATION
        AutoHealExecutionService.ExecutionResult res1 = AutoHealExecutionService.executeAction(incident.Id, 'SEND_NOTIFICATION');
        System.assert(res1.success);
        System.assertEquals('SEND_NOTIFICATION', res1.actionTaken);

        // Reset Execution Status to allow re-run
        incident.Execution_Status__c = 'Ready for Execution';
        update incident;

        // RETRY_SAFE_INTEGRATION
        AutoHealExecutionService.ExecutionResult res2 = AutoHealExecutionService.executeAction(incident.Id, 'RETRY_SAFE_INTEGRATION');
        System.assert(res2.success);
        System.assertEquals('RETRY_SAFE_INTEGRATION', res2.actionTaken);

        incident.Execution_Status__c = 'Ready for Execution';
        update incident;

        // UPDATE_SENTINELFLOW_STATUS
        AutoHealExecutionService.ExecutionResult res3 = AutoHealExecutionService.executeAction(incident.Id, 'UPDATE_SENTINELFLOW_STATUS');
        System.assert(res3.success);

        incident.Execution_Status__c = 'Ready for Execution';
        update incident;

        // RECOMMEND_RUNBOOK
        AutoHealExecutionService.ExecutionResult res4 = AutoHealExecutionService.executeAction(incident.Id, 'RECOMMEND_RUNBOOK');
        System.assert(res4.success);
    }

    @IsTest
    static void testExecuteAction_BlockedDangerousActions() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 30.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        // Check DELETE_RECORDS
        try {
            AutoHealExecutionService.executeAction(incident.Id, 'DELETE_RECORDS');
            System.assert(false, 'Should throw exception for blocked DELETE_RECORDS');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('Blocked Action'), 'Should contain block warning');
        }

        // Check BYPASS_APPROVAL
        try {
            AutoHealExecutionService.executeAction(incident.Id, 'BYPASS_APPROVAL');
            System.assert(false, 'Should throw exception for blocked BYPASS_APPROVAL');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('Blocked Action'));
        }

        // Check UNKNOWN action
        try {
            AutoHealExecutionService.executeAction(incident.Id, 'UNKNOWN_DANGER_ACTION');
            System.assert(false, 'Should throw exception for unknown action');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('Unsupported Action'));
        }
    }

    @IsTest
    static void testExecuteAction_KillSwitchActive() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 20.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        // Disable global Auto-Heal (Kill Switch active)
        SystemSettings.setOverride('Auto_Heal_Active', 0.0);

        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
            System.assert(false, 'Should throw exception when kill switch is active');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('disabled globally'), 'Expected kill switch message');
        }

        // Verify blocked audit log
        List<Sentinel_Audit_Log__c> logs = [
            SELECT Event_Type__c, Decision__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
        ];
        System.assert(!logs.isEmpty());
        System.assertEquals('AUTO_HEAL_BLOCKED', logs[0].Event_Type__c);
        System.assertEquals('KILL_SWITCH_ACTIVE', logs[0].Decision__c);
    }

    @IsTest
    static void testExecuteAction_ApprovalRequirement() {
        // Medium Risk, Pending Approval
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 55.0, // Medium Risk
            Approval_Status__c = 'Pending Approval',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        // Try to execute without approval
        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
            System.assert(false, 'Should block execution for unapproved medium risk incident');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('require human approval'), 'Expected approval required message');
        }

        // Set to Approved and run
        incident.Approval_Status__c = 'Approved';
        update incident;

        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
        System.assert(result.success, 'Should execute successfully after approval');
    }

    @IsTest
    static void testExecuteAction_DuplicatePrevention() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 25.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Executed',
            Status__c = 'Action Created'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
            System.assert(false, 'Should throw exception for already executed incident');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('already been executed'));
        }
    }

    @IsTest
    static void testExecuteAction_RollbackOnError() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 30.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'TEST_FORCE_FAILURE');
        Test.stopTest();

        System.assert(!result.success, 'Execution should fail');
        System.assert(result.message.contains('Forced testing failure'), 'Should capture failure message');

        // Verify database state: rolled back, execution status is Failed
        Sentinel_Incident__c updatedInc = [
            SELECT Status__c, Execution_Status__c, Created_Case__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Failed', updatedInc.Execution_Status__c);
    }
}
