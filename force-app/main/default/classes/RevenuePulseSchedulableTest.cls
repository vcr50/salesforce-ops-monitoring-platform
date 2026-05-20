/**
 * @description Test class for RevenuePulseSchedulable.
 * Validates scheduling, execution, abort, and job status retrieval.
 *
 * @group Tests
 */
@IsTest
private class RevenuePulseSchedulableTest {

    @TestSetup
    static void makeData() {
        // Create an open Incident so executePulseSync has data to process
        Incident__c inc = new Incident__c(
            Status__c       = 'Open',
            Severity__c     = 'High',
            Description__c  = 'Test incident for pulse scheduler'
        );
        insert inc;
    }

    @IsTest
    static void testExecute() {
        Test.startTest();
        // Schedule using the schedulable interface directly
        String jobId = System.schedule(
            'Test Revenue Pulse',
            '0 0 1 * * ?',
            new RevenuePulseSchedulable()
        );
        Test.stopTest();

        // Verify the job was registered
        List<CronTrigger> triggers = [
            SELECT Id, State FROM CronTrigger WHERE Id = :jobId
        ];
        Assert.isFalse(triggers.isEmpty(), 'Scheduled job should exist.');
    }

    @IsTest
    static void testScheduleDefault() {
        Test.startTest();
        String jobId = RevenuePulseSchedulable.scheduleDefault();
        Test.stopTest();

        Assert.isNotNull(jobId, 'scheduleDefault should return a job ID.');
    }

    @IsTest
    static void testScheduleDefaultIdempotent() {
        // Calling scheduleDefault twice should not throw — it aborts the old one first
        Test.startTest();
        RevenuePulseSchedulable.scheduleDefault();
        String jobId = RevenuePulseSchedulable.scheduleDefault();
        Test.stopTest();

        Assert.isNotNull(jobId, 'Second scheduleDefault call should still return a job ID.');
    }

    @IsTest
    static void testGetJobStatus_notScheduled() {
        RevenuePulseSchedulable.abortIfExists(RevenuePulseSchedulable.JOB_NAME);
        Map<String, Object> status = RevenuePulseSchedulable.getJobStatus();
        Assert.areEqual(false, status.get('isScheduled'), 'Job should not be scheduled.');
        Assert.areEqual('NOT_SCHEDULED', status.get('state'), 'State should be NOT_SCHEDULED.');
    }

    @IsTest
    static void testGetJobStatus_scheduled() {
        Test.startTest();
        RevenuePulseSchedulable.scheduleDefault();
        Map<String, Object> status = RevenuePulseSchedulable.getJobStatus();
        Test.stopTest();

        Assert.areEqual(true, status.get('isScheduled'), 'Job should be scheduled.');
        Assert.isNotNull(status.get('jobId'), 'Job ID should be present.');
    }
}

