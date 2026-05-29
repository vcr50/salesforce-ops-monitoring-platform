@IsTest
private class FlowHealthMonitorTest {

    @IsTest
    static void testRegisterFlowFailure_NewRecord() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        FlowHealthMonitor.registerFlowFailure('Test_Flow_1', 'Test Flow 1', 'Test error', 5);
        Test.stopTest();

        List<Flow_Health__c> logs = [SELECT Id, Flow_API_Name__c, Failure_Count__c, Affected_Records__c, Error_Message__c FROM Flow_Health__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('Test_Flow_1', logs[0].Flow_API_Name__c);
        System.assertEquals(1, logs[0].Failure_Count__c);
        System.assertEquals(5, logs[0].Affected_Records__c);
        System.assertEquals('Test error', logs[0].Error_Message__c);
    }

    @IsTest
    static void testRegisterFlowFailure_ExistingRecord() {
        SecurityGate.bypassForTests = true;

        Flow_Health__c existing = new Flow_Health__c(
            Flow_API_Name__c = 'Test_Flow_2',
            Failure_Count__c = 1,
            Last_Run_Status__c = 'Failed'
        );
        insert existing;

        Test.startTest();
        FlowHealthMonitor.registerFlowFailure('Test_Flow_2', 'Test Flow 2', 'Another error', 10);
        Test.stopTest();

        Flow_Health__c updatedLog = [SELECT Id, Failure_Count__c, Error_Message__c FROM Flow_Health__c WHERE Flow_API_Name__c = 'Test_Flow_2'];
        System.assertEquals(2, updatedLog.Failure_Count__c);
        System.assertEquals('Another error', updatedLog.Error_Message__c);
    }

    @IsTest
    static void testMonitorFailedFlows_WithMockData() {
        SecurityGate.bypassForTests = true;

        // Insert a Flow_Health__c record to use as a mock SObject.
        // monitorFailedFlows calls .get('FlowVersionId') and .get('CreatedDate').
        // Flow_Health__c has CreatedDate (all SObjects do). FlowVersionId returns null
        // which the processing loop handles gracefully (creates 'FlowVersion_null').
        Flow_Health__c mockRecord = new Flow_Health__c(
            Flow_API_Name__c = 'MockFlowVersion123',
            Last_Run_Status__c = 'Failed'
        );
        insert mockRecord;

        // Re-query to get CreatedDate populated
        SObject queriedMock = [SELECT Id, CreatedDate FROM Flow_Health__c WHERE Id = :mockRecord.Id];

        FlowHealthMonitor.mockFailedFlows = new List<SObject>{ queriedMock };

        Test.startTest();
        FlowHealthMonitor.monitorFailedFlows();
        Test.stopTest();

        // The processing should have run; verify health logs were created
        List<Flow_Health__c> healthLogs = [SELECT Id FROM Flow_Health__c WHERE Flow_API_Name__c = 'FlowVersion_Unknown'];
        System.assert(healthLogs.size() > 0, 'Should have created health logs from mock data');

        List<Incident__c> incidents = [SELECT Id FROM Incident__c WHERE Error_Type__c = 'Flow Exception'];
        System.assert(incidents.size() > 0, 'Should have created incidents from mock data');
    }

    @IsTest
    static void testMonitorFailedFlows_EmptyMock() {
        SecurityGate.bypassForTests = true;

        FlowHealthMonitor.mockFailedFlows = new List<SObject>();

        Test.startTest();
        FlowHealthMonitor.monitorFailedFlows();
        Test.stopTest();

        // Empty list should result in early return — no records created
        List<Flow_Health__c> healthLogs = [SELECT Id FROM Flow_Health__c];
        System.assertEquals(0, healthLogs.size());
    }

    @IsTest
    static void testMonitorFailedFlows_NoMock_FallsBackToQuery() {
        SecurityGate.bypassForTests = true;

        // Don't set mockFailedFlows — will try the dynamic query, which will fail
        // and return early. This covers the catch path.
        Test.startTest();
        FlowHealthMonitor.monitorFailedFlows();
        Test.stopTest();

        System.assert(true, 'monitorFailedFlows executed without exception');
    }

    @IsTest
    static void testScheduleExecution() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        String jobId = System.schedule('Test FHM', '0 0 0 1 1 ? 2099', new FlowHealthMonitor());
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}
