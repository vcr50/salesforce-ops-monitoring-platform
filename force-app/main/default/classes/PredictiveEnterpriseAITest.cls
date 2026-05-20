/**
 * PredictiveEnterpriseAITest
 * Test coverage for Phase 8 Predictive Enterprise AI.
 */
@IsTest
private class PredictiveEnterpriseAITest {

    @IsTest
    static void testForecastAnomalies_Stable() {
        // Since we don't have historical data in the test context naturally,
        // it will calculate 0 historical and 0 recent.
        Test.startTest();
        PredictiveEnterpriseAI.PredictionResult result = PredictiveEnterpriseAI.forecastAnomalies('Payment');
        Test.stopTest();
        
        System.assertEquals(0.00, result.anomalyScore);
        System.assertEquals(false, result.immediateActionRequired);
        System.assert(result.forecastMessage.contains('Stable'));
    }

    @IsTest
    static void testForecastAnomalies_Spike() {
        // Insert a bunch of events today to simulate a spike
        List<Universal_Event__c> events = new List<Universal_Event__c>();
        for (Integer i = 0; i < 10; i++) {
            events.add(new Universal_Event__c(
                Workflow_Stage__c = 'Payment',
                Revenue_Risk__c = 100,
                Status__c = 'New'
            ));
        }
        insert events;

        Test.startTest();
        PredictiveEnterpriseAI.PredictionResult result = PredictiveEnterpriseAI.forecastAnomalies('Payment');
        Test.stopTest();
        
        // 10 recent divided by daily baseline (which is minimum 1) = 10.0
        System.assertEquals(10.00, result.anomalyScore);
        System.assertEquals(true, result.immediateActionRequired);
        System.assert(result.forecastMessage.contains('CRITICAL FORECAST'));
    }
}

