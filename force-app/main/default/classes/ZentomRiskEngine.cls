public with sharing class ZentomRiskEngine {
    public class RiskScore {
        public Decimal totalScore;
        public Decimal technicalSeverity;
        public Decimal businessImpact;
        public Decimal blastRadius;
        public Decimal operationalContext;
    }

    /**
     * Quantifies the danger of an action based on four dimensions.
     */
    public static RiskScore evaluateRisk(Id incidentId, ZentomContextEngine.ContextPacket context) {
        RiskScore score = new RiskScore();
        
        // Technical Severity: Error class and depth in the stack
        score.technicalSeverity = 20.0;
        
        // Business Impact: Account ARR and tier from Salesforce
        if (context.accountARR > 100000) {
            score.businessImpact = 35.0;
        } else {
            score.businessImpact = 10.0;
        }
        
        // Blast Radius: Estimation of potential systemic damage
        score.blastRadius = 15.0;
        
        // Operational Context: Environmental signals
        score.operationalContext = 10.0;
        
        score.totalScore = score.technicalSeverity + score.businessImpact + score.blastRadius + score.operationalContext;
        return score;
    }
}

