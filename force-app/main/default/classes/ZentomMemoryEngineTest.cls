/**
 * Test class for ZentomMemoryEngine
 */
@IsTest
private class ZentomMemoryEngineTest {

    @IsTest
    static void testRetrieveMemoryForIncident() {
        // Setup data
        Id tenantId = TenantContext.getCurrentTenantId();
        
        AI_Decision__c decision = new AI_Decision__c(
            Tenant__c = tenantId,
            Root_Cause__c = 'Integration Timeout Exception',
            Executed_Action__c = 'Retry API Call',
            Reasoning__c = 'API normally recovers after 5 seconds',
            Confidence_Score__c = 95.0,
            Was_Accepted__c = true
        );
        insert decision;

        Test.startTest();
        ZentomMemoryEngine.HistoricalContext context = ZentomMemoryEngine.retrieveMemoryForIncident('ERP', 'Integration Timeout');
        Test.stopTest();

        System.assertEquals(true, context.wasSuccessful, 'Memory should be retrieved successfully');
        System.assertEquals('Retry API Call', context.previousResolution, 'Executed action should match');
        System.assertEquals(95.0, context.confidenceScore, 'Confidence score should match');
    }
}

