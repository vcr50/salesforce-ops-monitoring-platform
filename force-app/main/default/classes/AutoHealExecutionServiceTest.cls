@IsTest
private class AutoHealExecutionServiceTest {

    @TestSetup
    static void setupTestData() {
        SystemSettings.clearOverrides();
    }

    @IsTest
    static void testKillSwitchBlocksExecution() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 20.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        // Turn kill switch on (Active = 0.0)
        SystemSettings.setOverride('Auto_Heal_Active', 0.0);

        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
            System.assert(false, 'Should throw exception when kill switch is active');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('disabled globally'), 'Expected kill switch message');
        }

        // Verify audit log for kill switch block
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
    static void testDuplicateExecutionBlocked() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 25.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Executed',
            Execution_Action__c = 'CREATE_CASE',
            Status__c = 'Action Created'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
            System.assert(false, 'Should throw exception for duplicate execution');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('Duplicate Execution'), 'Expected duplicate execution exception');
        }
    }

    @IsTest
    static void testDuplicateBlockedAuditCreated() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 25.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Executed',
            Execution_Action__c = 'CREATE_CASE',
            Status__c = 'Action Created'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        try {
            AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');
        } catch (Exception e) {
            // Ignored
        }

        // Verify duplicate blocked audit log
        List<Sentinel_Audit_Log__c> logs = [
            SELECT Event_Type__c, Decision__c, Response_Payload__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
            ORDER BY CreatedDate DESC
        ];
        System.assert(!logs.isEmpty(), 'Audit log should be created for duplicate attempt');
        System.assertEquals('AUTO_HEAL_BLOCKED', logs[0].Event_Type__c);
        System.assertEquals('DUPLICATE_EXECUTION', logs[0].Decision__c);
    }

    @IsTest
    static void testConcurrentLockPreventsDoubleExecution() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 30.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Id deletedId = incident.Id;
        delete incident; // delete record to simulate query failure (locked or missing)

        try {
            AutoHealExecutionService.executeAction(deletedId, 'CREATE_CASE');
            System.assert(false, 'Should throw exception when lock/query fails');
        } catch (AutoHealExecutionService.AutoHealException e) {
            System.assert(e.getMessage().contains('Failed to lock'), 'Expected lock failure message');
        }

        // Verify lock failure audit log
        List<Sentinel_Audit_Log__c> logs = [
            SELECT Event_Type__c, Decision__c
            FROM Sentinel_Audit_Log__c
            WHERE Trace_Id__c = :String.valueOf(deletedId)
        ];
        System.assert(!logs.isEmpty(), 'Lock failure audit log should have been created');
        System.assertEquals('AUTO_HEAL_BLOCKED', logs[0].Event_Type__c);
        System.assertEquals('LOCK_FAILURE', logs[0].Decision__c);
    }

    @IsTest
    static void testCreateCaseAction() {
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

        System.assert(result.success);
        System.assertEquals('CREATE_CASE', result.actionTaken);

        Sentinel_Incident__c updatedInc = [
            SELECT Status__c, Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Action Created', updatedInc.Status__c);
        System.assertEquals('Executed', updatedInc.Execution_Status__c);
    }

    @IsTest
    static void testCreateTaskAction() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 75.0,
            Approval_Status__c = 'Approved',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'Approved'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');
        Test.stopTest();

        System.assert(result.success);
        Task t = [SELECT Priority FROM Task WHERE Id = :result.recordId LIMIT 1];
        System.assertEquals('High', t.Priority);
    }

    @IsTest
    static void testSendNotificationAction() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 15.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'SEND_NOTIFICATION');
        Test.stopTest();

        System.assert(result.success);
    }

    @IsTest
    static void testRetrySafeIntegrationAction() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 30.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New',
            Runbook_Key__c = 'RB_INTEGRATION_RETRY'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'RETRY_SAFE_INTEGRATION');
        Test.stopTest();

        System.assert(result.success);
    }

    @IsTest
    static void testUpdateSentinelFlowStatusAction() {
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
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'UPDATE_SENTINELFLOW_STATUS');
        Test.stopTest();

        System.assert(result.success);
    }

    @IsTest
    static void testRecommendRunbookAction() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'System Incident',
            Risk_Score__c = 10.0,
            Approval_Status__c = 'Not Required',
            Execution_Status__c = 'Ready for Execution',
            Status__c = 'New',
            Runbook_Title__c = 'Zoho API Timeout Resolution'
        );
        insert incident;

        SystemSettings.setOverride('Auto_Heal_Active', 1.0);

        Test.startTest();
        AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'RECOMMEND_RUNBOOK');
        Test.stopTest();

        System.assert(result.success);
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

        System.assert(!result.success);
        Sentinel_Incident__c updatedInc = [
            SELECT Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incident.Id
        ];
        System.assertEquals('Failed', updatedInc.Execution_Status__c);
    }
}
