public with sharing class SentinelPredictionEngine {
    
    public static void evaluateSignals(List<Sentinel_Anomaly_Signal__c> signals) {
        if (signals == null || signals.isEmpty()) return;
        
        System.enqueueJob(new SentinelPredictionQueueable(signals));
    }
    
    public static void processSignals(List<Sentinel_Anomaly_Signal__c> signals) {
        // Group signals by Event_Source__c to create predictions per source
        Map<String, List<Sentinel_Anomaly_Signal__c>> sourceToSignals = new Map<String, List<Sentinel_Anomaly_Signal__c>>();
        for (Sentinel_Anomaly_Signal__c sig : signals) {
            if (String.isNotBlank(sig.Event_Source__c)) {
                if (!sourceToSignals.containsKey(sig.Event_Source__c)) {
                    sourceToSignals.put(sig.Event_Source__c, new List<Sentinel_Anomaly_Signal__c>());
                }
                sourceToSignals.get(sig.Event_Source__c).add(sig);
            }
        }
        
        List<Sentinel_Prediction__c> predictionsToInsert = new List<Sentinel_Prediction__c>();
        Map<String, SentinelPredictionScoringService.ScoringInput> inputsMap = new Map<String, SentinelPredictionScoringService.ScoringInput>();
        
        for (String source : sourceToSignals.keySet()) {
            SentinelPredictionScoringService.ScoringInput input = new SentinelPredictionScoringService.ScoringInput();
            input.errorVelocity = 0;
            input.retrySpikeCount = 0;
            input.flowFailureCount = 0;
            input.integrationFailureRate = 0;
            input.businessImpactScore = 0;
            input.historicalRecurrenceFactor = 0;
            input.orgHealthDegradationRate = 0;
            
            for (Sentinel_Anomaly_Signal__c sig : sourceToSignals.get(source)) {
                if (sig.Signal_Type__c == 'Apex Exception' || sig.Signal_Type__c == 'Error Velocity') {
                    input.errorVelocity += sig.Metric_Value__c != null ? sig.Metric_Value__c : 0;
                } else if (sig.Signal_Type__c == 'Retry Spike') {
                    input.retrySpikeCount += Integer.valueOf(sig.Metric_Value__c != null ? sig.Metric_Value__c : 0);
                } else if (sig.Signal_Type__c == 'Deployment Activity') {
                    input.minutesSinceDeployment = Integer.valueOf(sig.Metric_Value__c != null ? sig.Metric_Value__c : 0);
                } else if (sig.Signal_Type__c == 'Flow Failure') {
                    input.flowFailureCount += Integer.valueOf(sig.Metric_Value__c != null ? sig.Metric_Value__c : 0);
                } else if (sig.Signal_Type__c == 'Integration Error' || sig.Signal_Type__c == 'Integration Failure') {
                    input.integrationFailureRate += sig.Metric_Value__c != null ? sig.Metric_Value__c : 0;
                }
            }
            
            SentinelPredictionScoringService service = new SentinelPredictionScoringService();
            SentinelPredictionScoringService.ScoringResult res = service.calculateScore(input);
            
            if (res.probabilityScore >= 40) {
                Sentinel_Prediction__c pred = new Sentinel_Prediction__c();
                pred.Prediction_Score__c = res.probabilityScore;
                pred.Confidence_Score__c = res.confidenceScore;
                pred.Status__c = res.probabilityScore >= 70 ? 'Critical' : 'Warning';
                pred.Summary__c = 'Potential anomaly detected in ' + source;
                pred.Explanation__c = SentinelPredictionExplanationService.generateExplanation(res.probabilityScore, res.confidenceScore, input);
                pred.Operator_Decision__c = 'Pending';
                
                predictionsToInsert.add(pred);
                inputsMap.put(source, input);
            }
        }
        
        if (!predictionsToInsert.isEmpty()) {
            insert as user predictionsToInsert;
        }
    }
}
