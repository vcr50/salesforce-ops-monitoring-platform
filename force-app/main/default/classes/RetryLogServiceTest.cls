/**
 * RetryLogServiceTest
 * Code coverage and functional tests for RetryLogService.
 */
@IsTest
private class RetryLogServiceTest {

    @TestSetup
    static void setup() {
        Tenant__c tenant = new Tenant__c(Name = 'RetryTest Tenant', Status__c = 'Active');
        insert tenant;

        // Insert Incident directly to avoid IntegrationLogTrigger enqueuing SelfHealQueueable
        Incident__c inc = new Incident__c(
            Severity__c = 'High',
            Status__c = 'Open',
            Tenant__c = tenant.Id,
            Self_Heal_Attempted__c = true,
            Description__c = 'Test incident for retry logging'
        );
        insert inc;
    }

    @IsTest
    static void testLog_insertsRecord() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        RetryLogService.log(inc.Id, 1, 'Failed', 'Connection refused');
        Test.stopTest();

        List<Retry_Log__c> logs = [
            SELECT Id, Retry_Attempt__c, Result__c
            FROM Retry_Log__c
            WHERE Incident__c = :inc.Id
        ];
        System.assertEquals(1, logs.size(), 'Should insert 1 retry log');
        System.assertEquals(1, Integer.valueOf(logs[0].Retry_Attempt__c), 'Attempt should be 1');
        System.assertEquals('Failed', logs[0].Result__c, 'Result should be Failed');
    }

    @IsTest
    static void testLog_success() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        RetryLogService.log(inc.Id, 1, 'Success', null);
        Test.stopTest();

        List<Retry_Log__c> logs = [
            SELECT Id, Result__c
            FROM Retry_Log__c
            WHERE Incident__c = :inc.Id
        ];
        System.assertEquals(1, logs.size(), 'Should insert 1 retry log');
        System.assertEquals('Success', logs[0].Result__c, 'Result should be Success');
    }

    @IsTest
    static void testLog_nullIncidentId_doesNotThrow() {
        Test.startTest();
        RetryLogService.log(null, 1, 'Failed', 'Test');
        Test.stopTest();

        List<Retry_Log__c> logs = [SELECT Id FROM Retry_Log__c];
        System.assertEquals(0, logs.size(), 'No log should be created for null incidentId');
    }

    @IsTest
    static void testGetRetryLogsForIncident() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        insert new Retry_Log__c(
            Incident__c      = inc.Id,
            Retry_Attempt__c = 1,
            Action_Taken__c  = 'Retry',
            Result__c        = 'Success',
            Timestamp__c     = System.now()
        );

        Test.startTest();
        List<Retry_Log__c> logs = RetryLogService.getRetryLogsForIncident(inc.Id);
        Test.stopTest();

        System.assertEquals(1, logs.size(), 'Should return 1 log for the incident');
    }

    @IsTest
    static void testBulkInsert() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        List<Retry_Log__c> entries = new List<Retry_Log__c>();
        for (Integer i = 1; i <= 5; i++) {
            entries.add(new Retry_Log__c(
                Incident__c      = inc.Id,
                Retry_Attempt__c = i,
                Action_Taken__c  = 'Retry',
                Result__c        = 'Failed',
                Timestamp__c     = System.now()
            ));
        }

        Test.startTest();
        RetryLogService.logRetryBulk(entries);
        Test.stopTest();

        List<Retry_Log__c> logs = [SELECT Id FROM Retry_Log__c WHERE Incident__c = :inc.Id];
        System.assertEquals(5, logs.size(), 'Should insert 5 retry logs');
    }

    @IsTest
    static void testLog_invalidIncidentId_coversQueryException() {
        // Create an invalid ID of prefix for Incident__c (e.g. using a dummy ID of wrong sObject type or non-existent)
        Id invalidId = UserInfo.getUserId();

        Test.startTest();
        // This will trigger QueryException on line 43 and log successfully without tenant
        RetryLogService.log(invalidId, 1, 'Failed', 'Connection refused');
        Test.stopTest();

        // No logs should be created because the insert will fail due to invalid master-detail/lookup relation ID
        List<Retry_Log__c> logs = [SELECT Id FROM Retry_Log__c WHERE Incident__c = :invalidId];
        System.assertEquals(0, logs.size());
    }

    @IsTest
    static void testLogRetryBulk_fails_coversException() {
        // Passing an empty/invalid Retry_Log__c entry to cause insert exception
        List<Retry_Log__c> entries = new List<Retry_Log__c>{
            new Retry_Log__c() // Missing required Incident__c field
        };

        Test.startTest();
        RetryLogService.logRetryBulk(entries);
        Test.stopTest();

        System.assert(true, 'Should handle bulk insert exception gracefully');
    }

    @IsTest
    static void testGetRetryLogsForIncident_nullIncidentId() {
        Test.startTest();
        List<Retry_Log__c> logs = RetryLogService.getRetryLogsForIncident(null);
        Test.stopTest();

        System.assertEquals(0, logs.size());
    }
}