public with sharing class SentinelPredictionExplanationService {
    public static String generateExplanation(Decimal probability, Decimal confidence, SentinelPredictionScoringService.ScoringInput input) {
        String baseStr = 'Outage probability calculated at ' + probability + '% (Confidence: ' + confidence + '%)';
        List<String> reasons = new List<String>();
        
        if (input.minutesSinceDeployment != null && input.minutesSinceDeployment <= 45) {
            reasons.add('a metadata deployment occurred ' + input.minutesSinceDeployment + ' minutes ago');
        }
        if (input.integrationFailureRate != null && input.integrationFailureRate >= 40) {
            reasons.add('integration failures spiked to ' + input.integrationFailureRate + '%');
        }
        if (input.errorVelocity != null && input.errorVelocity >= 40) {
            reasons.add('system error velocity increased significantly');
        }
        if (input.flowFailureCount != null && input.flowFailureCount >= 4) {
            reasons.add('multiple flow failures were detected');
        }
        if (input.retrySpikeCount != null && input.retrySpikeCount >= 2) {
            reasons.add('asynchronous retry limits are being approached');
        }
        
        if (!reasons.isEmpty()) {
            baseStr += ' because ' + String.join(reasons, ' and ') + ' within the last rolling window.';
        } else {
            baseStr += ' based on recent anomalous system activity.';
        }
        return baseStr;
    }
}
