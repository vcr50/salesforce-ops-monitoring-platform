/**
 * AIAnalysisQueueableTest
 * Code coverage and functional tests for AIAnalysisQueueable.
 */
@IsTest
private class AIAnalysisQueueableTest {

    @TestSetup
    static void setup() {
        Tenant__c tenant = new Tenant__c(Name = 'Test Tenant', Status__c = 'Active');
        insert tenant;

        Incident__c inc = new Incident__c(
            Severity__c        = 'High',
            Status__c          = 'Open',
            Tenant__c          = tenant.Id,
            Description__c     = 'Test incident'
        );
        insert inc;
    }

    @IsTest
    static void testExecute() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new AIAnalysisQueueable(inc.Id));
        Test.stopTest();

        Incident__c updatedInc = [SELECT Id, Status__c FROM Incident__c LIMIT 1];
        System.assertEquals('Analyzing', updatedInc.Status__c, 'Status should be Analyzing');
    }

    @IsTest
    static void testExecuteList() {
        List<Incident__c> incs = [SELECT Id FROM Incident__c];
        List<Id> ids = new List<Id>();
        for (Incident__c inc : incs) {
            ids.add(inc.Id);
        }

        Test.startTest();
        System.enqueueJob(new AIAnalysisQueueable(ids));
        Test.stopTest();

        Incident__c updatedInc = [SELECT Id, Status__c FROM Incident__c LIMIT 1];
        System.assertEquals('Analyzing', updatedInc.Status__c, 'Status should be Analyzing');
    }

    @IsTest
    static void testExecute_HighConfidence() {
        Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
        Integration_Log__c log = new Integration_Log__c(
            API_Name__c = 'Test API',
            Status__c = 'Failed',
            Error_Message__c = 'Timeout occurred',
            Tenant__c = tenant.Id
        );
        insert log;

        Incident__c inc = new Incident__c(
            Severity__c        = 'High',
            Status__c          = 'New',
            Tenant__c          = tenant.Id,
            Integration_Log__c = log.Id,
            Description__c     = 'Test high confidence'
        );
        insert inc;

        Test.startTest();
        System.enqueueJob(new AIAnalysisQueueable(inc.Id));
        Test.stopTest();

        Incident__c updatedInc = [SELECT Id, Status__c FROM Incident__c WHERE Id = :inc.Id LIMIT 1];
        System.assertEquals('Analyzing', updatedInc.Status__c, 'Status should be Analyzing');
    }

    @IsTest
    static void testExecute_Exception() {
        // Pass a fake ID to trigger a QueryException in AIAnalysisService
        Id fakeId = 'a00000000000000AAA';

        Test.startTest();
        System.enqueueJob(new AIAnalysisQueueable(new List<Id>{fakeId}, 0));
        Test.stopTest();

        // Check if System_Log__c was created
        Integer logCount = [SELECT COUNT() FROM System_Log__c WHERE Class_Name__c = 'AIAnalysisQueueable'];
        System.assertEquals(1, logCount, 'Should have logged a permanent error');
    }
}
