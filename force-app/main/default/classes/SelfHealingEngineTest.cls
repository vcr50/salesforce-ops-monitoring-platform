/**
 * SelfHealingEngineTest
 * Code coverage and functional tests for SelfHealingEngine.
 */
@IsTest
private class SelfHealingEngineTest {

    @TestSetup
    static void setup() {
        SentinelFlow_Settings__c settings = new SentinelFlow_Settings__c(
            Enable_Alerts__c = true,
            Endpoint_Active__c = true,
            Max_Retry__c = 3
        );
        insert settings;

        Tenant__c tenant = new Tenant__c(Name = 'Test Tenant', Status__c = 'Active');
        insert tenant;

        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'Test Endpoint',
            Circuit_Status__c = 'Closed',
            Failure_Count__c = 0
        );
        insert endpoint;

        Integration_Log__c log = new Integration_Log__c(
            API_Name__c = 'SAP ERP',
            Status__c   = 'Failed',
            Error_Message__c = 'Timeout',
            Tenant__c   = tenant.Id
        );
        insert log;
        
        // Delete the auto-created incident from the log trigger to avoid conflicts
        delete [SELECT Id FROM Incident__c];

        Incident__c inc = new Incident__c(
            Severity__c        = 'High',
            Status__c          = 'New',
            Integration_Log__c = log.Id,
            Integration_Endpoint__c = endpoint.Id,
            Tenant__c          = tenant.Id,
            Retry_Count__c     = 0,
            Self_Heal_Attempted__c = false,
            Description__c     = 'Test incident'
        );
        insert inc;
    }

    @IsTest
    static void testProcessFailedLogs() {
        Incident__c incBefore = [SELECT Id FROM Incident__c LIMIT 1];
        incBefore.Self_Heal_Attempted__c = false;
        update incBefore;

        Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];
        
        Test.startTest();
        SelfHealingEngine.processFailedLogs(new List<Id>{log.Id});
        Test.stopTest();

        Incident__c inc = [SELECT Id, Status__c, Auto_Heal_Status__c, Self_Heal_Attempted__c FROM Incident__c LIMIT 1];
        System.assertEquals(true, inc.Self_Heal_Attempted__c, 'Self heal should be attempted');
    }

    @IsTest
    static void testProcessFailedLogs_CircuitOpen() {
        Integration_Endpoint__c ep = [SELECT Id FROM Integration_Endpoint__c LIMIT 1];
        ep.Circuit_Status__c = 'Open';
        update ep;

        Incident__c incBefore = [SELECT Id FROM Incident__c LIMIT 1];
        incBefore.Self_Heal_Attempted__c = false;
        update incBefore;

        Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];
        
        Test.startTest();
        SelfHealingEngine.processFailedLogs(new List<Id>{log.Id});
        Test.stopTest();

        Incident__c inc = [SELECT Id, Status__c, Auto_Heal_Status__c FROM Incident__c LIMIT 1];
        List<System_Log__c> logs = [SELECT Exception_Message__c FROM System_Log__c];
        if (!logs.isEmpty()) {
            System.assert(false, 'Exception caught: ' + logs[0].Exception_Message__c);
        }

        System.assertEquals('Escalated', inc.Status__c, 'Should be escalated immediately if circuit open');
        System.assertEquals('Failed', inc.Auto_Heal_Status__c, 'Auto heal status should be failed');
    }

    @IsTest
    static void testHealIncident_RetrySuccess() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
        inc.Recommended_Action__c = 'Retry';
        update inc;

        Test.startTest();
        SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Retry action should succeed');
        System.assertEquals('Retry', result.actionTaken, 'Action taken should be Retry');

        Incident__c updatedInc = [SELECT Id, Status__c, Auto_Heal_Status__c, Retry_Count__c FROM Incident__c LIMIT 1];
        System.assertEquals('Resolved', updatedInc.Status__c, 'Status should be Resolved');
        System.assertEquals('Succeeded', updatedInc.Auto_Heal_Status__c, 'Auto heal status should be Succeeded');
        System.assertEquals(1, updatedInc.Retry_Count__c, 'Retry count should be incremented');
    }

    @IsTest
    static void testHealIncident_MaxRetriesReached() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
        inc.Recommended_Action__c = 'Retry';
        inc.Retry_Count__c = 3; // Equal to Max_Retry__c
        update inc;

        Test.startTest();
        SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Action should fail due to max retries');
        System.assertEquals('Escalate', result.actionTaken, 'Action taken should be Escalate');

        Incident__c updatedInc = [SELECT Id, Status__c, Auto_Heal_Status__c, Retry_Count__c FROM Incident__c LIMIT 1];
        System.assertEquals('Escalated', updatedInc.Status__c, 'Status should be Escalated');
        System.assertEquals('Failed', updatedInc.Auto_Heal_Status__c, 'Auto heal status should be Failed');
    }

    @IsTest
    static void testHealIncident_Restart() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
        inc.Recommended_Action__c = 'Restart Service';
        update inc;

        Test.startTest();
        SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Restart action should succeed');
        System.assertEquals('Restart Service', result.actionTaken, 'Action taken should be Restart Service');
    }

    @IsTest
    static void testHealIncident_TokenRefresh() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
        inc.Recommended_Action__c = 'Token Refresh';
        update inc;

        Test.startTest();
        SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Token Refresh action should succeed');
        System.assertEquals('Token Refresh', result.actionTaken, 'Action taken should be Token Refresh');
    }

    @IsTest
    static void testHealIncident_Escalate() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
        inc.Recommended_Action__c = 'Escalate';
        update inc;

        Test.startTest();
        SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Escalate action should succeed');
        System.assertEquals('Escalate', result.actionTaken, 'Action taken should be Escalate');
    }
}
