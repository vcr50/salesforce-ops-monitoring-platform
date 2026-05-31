public with sharing class SentinelPredictionScoringService {
    public class ScoringInput {
        public Decimal errorVelocity;
        public Integer retrySpikeCount;
        public Integer minutesSinceDeployment;
        public Integer flowFailureCount;
        public Decimal integrationFailureRate;
        public Decimal businessImpactScore;
        public Decimal historicalRecurrenceFactor;
        public Decimal orgHealthDegradationRate;
    }
    
    public class ScoringResult {
        public Decimal probabilityScore;
        public Decimal confidenceScore;
    }
    
    public ScoringResult calculateScore(ScoringInput input) {
        ScoringResult result = new ScoringResult();
        
        // 1. Get Weights (Milestone 58B Tuned — total normalized to 1.0)
        // Dominant: Deployment (w3=0.45) and Error/CPU/Apex (w1=0.25)
        // Reduced: Integration, Retry, Flow, Health, Business, History
        Decimal w3 = SystemSettings.get('Prediction_Weight_Deployment', 0.45);
        Decimal w1 = SystemSettings.get('Prediction_Weight_Error', 0.25);
        Decimal w5 = SystemSettings.get('Prediction_Weight_Integration', 0.10);
        Decimal w4 = SystemSettings.get('Prediction_Weight_Flow', 0.06);
        Decimal w2 = SystemSettings.get('Prediction_Weight_Retry', 0.06);
        Decimal w8 = SystemSettings.get('Prediction_Weight_Health', 0.05);
        Decimal w6 = SystemSettings.get('Prediction_Weight_Business', 0.02);
        Decimal w7 = SystemSettings.get('Prediction_Weight_History', 0.01);
        
        // Normalize S3 (Deployment)
        Decimal s3 = 0;
        if (input.minutesSinceDeployment != null) {
            if (input.minutesSinceDeployment <= 15) s3 = 100;
            else if (input.minutesSinceDeployment <= 45) s3 = 50;
        }
        
        // Normalize others
        Decimal s1 = Math.min(100, input.errorVelocity != null ? input.errorVelocity : 0);
        Decimal s2 = Math.min(100, (input.retrySpikeCount != null ? input.retrySpikeCount : 0) * 20); // Scale up
        Decimal s4 = Math.min(100, (input.flowFailureCount != null ? input.flowFailureCount : 0) * 10);
        Decimal s5 = Math.min(100, input.integrationFailureRate != null ? input.integrationFailureRate : 0);
        Decimal s6 = Math.min(100, input.businessImpactScore != null ? input.businessImpactScore : 0);
        Decimal s7 = Math.min(100, input.historicalRecurrenceFactor != null ? input.historicalRecurrenceFactor : 0);
        Decimal s8 = Math.min(100, input.orgHealthDegradationRate != null ? input.orgHealthDegradationRate : 0);
        
        // Calculate Probability
        Decimal prob = (s3 * w3) + (s5 * w5) + (s1 * w1) + (s4 * w4) + (s2 * w2) + (s8 * w8) + (s6 * w6) + (s7 * w7);
        result.probabilityScore = Math.min(100, prob).setScale(2);
        
        // Confidence calculation
        Integer warningSignals = 0;
        Integer activeSignals = 0;
        
        if (s1 > 0) { activeSignals++; if (s1 >= 40) warningSignals++; }
        if (s2 > 0) { activeSignals++; if (s2 >= 40) warningSignals++; }
        if (s3 > 0) { activeSignals++; if (s3 >= 40) warningSignals++; }
        if (s4 > 0) { activeSignals++; if (s4 >= 40) warningSignals++; }
        if (s5 > 0) { activeSignals++; if (s5 >= 40) warningSignals++; }
        if (s6 > 0) { activeSignals++; if (s6 >= 40) warningSignals++; }
        if (s7 > 0) { activeSignals++; if (s7 >= 40) warningSignals++; }
        if (s8 > 0) { activeSignals++; if (s8 >= 40) warningSignals++; }
        
        Decimal cBase = 0;
        if (activeSignals > 0) {
            cBase = (Decimal.valueOf(warningSignals) / Decimal.valueOf(activeSignals)) * 100;
        } else {
            cBase = 100; 
        }
        
        Decimal dCompleteness = 1.0; 
        Decimal tRecency = 1.0; 
        
        Decimal conf = cBase * dCompleteness * tRecency;
        result.confidenceScore = Math.min(100, Math.max(0, conf)).setScale(2);
        
        return result;
    }
}
