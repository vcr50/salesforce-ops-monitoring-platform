@IsTest
private class ApexJobMonitorTest {

    private class FailingQueueable implements Queueable {
        public void execute(QueueableContext context) {
            Integer i = 1 / 0; // Throws exception to fail the job
        }
    }

    @TestSetup
    static void setup() {
        SecurityGate.bypassForTests = true;
    }

    @IsTest
    static void testMonitorFailedJobs() {
        SecurityGate.bypassForTests = true;

        String jsonStr = '[{"attributes":{"type":"AsyncApexJob"}, "Id":"707000000000000", "Status":"Failed", "JobType":"BatchApex", "ExtendedStatus":"Test Exception"}]';
        ApexJobMonitor.mockFailedJobs = (List<AsyncApexJob>) JSON.deserialize(jsonStr, List<AsyncApexJob>.class);

        // Now run the monitor
        ApexJobMonitor.monitorFailedJobsInternal();

        // Verify incidents created
        List<Incident__c> incidents = [SELECT Id, Error_Type__c FROM Incident__c WHERE Error_Type__c = 'Apex Exception'];
        System.assert(incidents.size() > 0, 'Should have created incidents for failed apex jobs');
    }

    @IsTest
    static void testScheduledExecution() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        String jobId = System.schedule('Test Monitor', '0 0 0 1 1 ? 2099', new ApexJobMonitor());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');
    }
}
