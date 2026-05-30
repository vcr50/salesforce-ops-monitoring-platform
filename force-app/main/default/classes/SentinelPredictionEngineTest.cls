@IsTest
private class SentinelPredictionEngineTest {
    
    @IsTest
    static void testScoringCalculation() {
        SentinelPredictionScoringService.ScoringInput input = new SentinelPredictionScoringService.ScoringInput();
        input.minutesSinceDeployment = 10;
        input.integrationFailureRate = 80;
        input.errorVelocity = 50;
        
        SentinelPredictionScoringService service = new SentinelPredictionScoringService();
        SentinelPredictionScoringService.ScoringResult res = service.calculateScore(input);
        
        System.assertNotEquals(null, res.probabilityScore, 'Probability score should not be null');
        System.assertNotEquals(null, res.confidenceScore, 'Confidence score should not be null');
        System.assertEquals(65.50, res.probabilityScore, 'Expected exactly 65.50 for this scenario under tuned weights');
    }
    
    @IsTest
    static void testExplanationGeneration() {
        SentinelPredictionScoringService.ScoringInput input = new SentinelPredictionScoringService.ScoringInput();
        input.minutesSinceDeployment = 10;
        input.integrationFailureRate = 80;
        input.errorVelocity = 50;
        
        String expl = SentinelPredictionExplanationService.generateExplanation(65.50, 90.0, input);
        System.assert(expl.contains('65.5'), 'Should contain probability score');
        System.assert(expl.contains('deployment occurred'), 'Should mention deployment');
        System.assert(expl.contains('integration failures'), 'Should mention integration failures');
    }
    
    @IsTest
    static void testEngineBulkProcessing() {
        List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
        
        for (Integer i = 0; i < 200; i++) {
            // Integration Failure signal (weight 0.10)
            signals.add(new Sentinel_Anomaly_Signal__c(
                Event_Source__c = 'Payment Gateway ' + Math.mod(i, 5),
                Signal_Type__c = 'Integration Failure',
                Metric_Value__c = 100
            ));
            // Deployment Activity signal (weight 0.45) to push above the 40% noise suppression threshold
            signals.add(new Sentinel_Anomaly_Signal__c(
                Event_Source__c = 'Payment Gateway ' + Math.mod(i, 5),
                Signal_Type__c = 'Deployment Activity',
                Metric_Value__c = 10
            ));
        }
        
        Test.startTest();
        SentinelPredictionEngine.processSignals(signals);
        Test.stopTest();
        
        List<Sentinel_Prediction__c> preds = [SELECT Id, Prediction_Score__c, Status__c, Summary__c FROM Sentinel_Prediction__c];
        System.assertEquals(5, preds.size(), 'Should create one prediction per event source');
        for (Sentinel_Prediction__c p : preds) {
            System.assertEquals(55.0, p.Prediction_Score__c, 'Score should be calculated (100 * 0.10 + 100 * 0.45 = 55)');
        }
    }
    
    @IsTest
    static void testQueueableExecution() {
        List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
        signals.add(new Sentinel_Anomaly_Signal__c(
            Event_Source__c = 'Checkout API',
            Signal_Type__c = 'Integration Failure',
            Metric_Value__c = 100
        ));
        signals.add(new Sentinel_Anomaly_Signal__c(
            Event_Source__c = 'Checkout API',
            Signal_Type__c = 'Deployment Activity',
            Metric_Value__c = 5
        ));
        
        Test.startTest();
        SentinelPredictionEngine.evaluateSignals(signals);
        Test.stopTest();
        
        List<Sentinel_Prediction__c> preds = [SELECT Id, Prediction_Score__c, Status__c FROM Sentinel_Prediction__c];
        System.assertEquals(1, preds.size(), 'Queueable should process and insert one prediction');
        System.assertEquals(55.0, preds[0].Prediction_Score__c, 'Score should be 100*0.45 + 100*0.10 = 55');
        System.assertEquals('Warning', preds[0].Status__c, 'Status should be Warning');
    }
}
