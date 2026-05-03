/**
 * ScheduledMonitoringJobTest
 * Code coverage and functional tests for ScheduledMonitoringJob.
 */
@IsTest
private class ScheduledMonitoringJobTest {

    @TestSetup
    static void setup() {
        Tenant__c tenant = new Tenant__c(Name = 'Test Tenant', Status__c = 'Active');
        insert tenant;

        // Create a failed log that is "old" — we'll manipulate via Test.setCreatedDate workaround
        Integration_Log__c log = new Integration_Log__c(
            API_Name__c      = 'Stripe Test API',
            Status__c        = 'Failed',
            Error_Message__c = 'Connection timeout',
            Tenant__c        = tenant.Id
        );
        insert log;
    }

    @IsTest
    static void testSweepStaleFailed_createsIncident() {
        ScheduledMonitoringJob.STALE_FAILURE_MINUTES = -1;
        // The IntegrationLogTrigger auto-created an incident for the log inserted in setup.
        // We must delete it so that sweepStaleFailed can process it as a "Silent Failure".
        delete [SELECT Id FROM Incident__c];

        Test.startTest();
        ScheduledMonitoringJob.sweepStaleFailed();
        Test.stopTest();

        List<Incident__c> incidents = [
            SELECT Id, Error_Type__c, Status__c
            FROM Incident__c
            WHERE Error_Type__c = 'Silent Failure'
        ];
        System.assertEquals(1, incidents.size(), 'Should have created 1 incident for stale failed log');
        System.assertEquals('Analyzing', incidents[0].Status__c, 'Incident status should be Analyzing');
    }

    @IsTest
    static void testSweepStaleFailed_skipsLogWithExistingIncident() {
        ScheduledMonitoringJob.STALE_FAILURE_MINUTES = -1;

        Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

        // The trigger already created an open incident for this log. We don't need to insert a new one.
        // Just verify sweepStaleFailed doesn't create another one.

        Test.startTest();
        ScheduledMonitoringJob.sweepStaleFailed();
        Test.stopTest();

        // Should still be only 1 incident (the pre-existing one)
        List<Incident__c> allIncidents = [SELECT Id FROM Incident__c];
        System.assertEquals(1, allIncidents.size(), 'Should not create duplicate incident');
    }

    @IsTest
    static void testScheduledExecution() {
        ScheduledMonitoringJob.STALE_FAILURE_MINUTES  = -1;
        ScheduledMonitoringJob.SILENT_FAILURE_MINUTES = -1;

        String cronExpr = '0 0 0 1 1 ? 2099';
        Test.startTest();
        System.schedule('TestSentinelFlowMonitor', cronExpr, new ScheduledMonitoringJob());
        Test.stopTest();

        // Verify the schedule was created
        List<CronTrigger> triggers = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'TestSentinelFlowMonitor'
        ];
        System.assertEquals(1, triggers.size(), 'Scheduled job should exist');
    }
}
