/**
 * @description Business Safety Score Engine — Phase 3 Deliverable.
 * Calculates a composite "Business Safety Score" (0-100) representing
 * the overall safety of revenue and operational workflows.
 */
public with sharing class BusinessSafetyScore {

    public class SafetyReport {
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public String grade { get; set; }
        @AuraEnabled public String verdict { get; set; }
        @AuraEnabled public Decimal revenueProtected { get; set; }
        @AuraEnabled public Decimal revenueAtRisk { get; set; }
        @AuraEnabled public Integer activeThreats { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SafetyReport calculate() {
        SafetyReport report = new SafetyReport();

        // Revenue at risk
        List<AggregateResult> riskAgg = [
            SELECT SUM(Risk_Amount__c) amt FROM Revenue_Risk__c WHERE Status__c = 'Open'
        ];
        report.revenueAtRisk = riskAgg.isEmpty() || riskAgg[0].get('amt') == null
            ? 0 : (Decimal) riskAgg[0].get('amt');

        // Pipeline (revenue protected = pipeline - at risk)
        List<AggregateResult> pipeAgg = [
            SELECT SUM(Amount) amt FROM Opportunity WHERE IsClosed = false
        ];
        Decimal pipeline = pipeAgg.isEmpty() || pipeAgg[0].get('amt') == null ? 0 : (Decimal) pipeAgg[0].get('amt');
        report.revenueProtected = Math.max(0, pipeline - report.revenueAtRisk);

        // Active threats
        report.activeThreats = [
            SELECT COUNT() FROM Incident__c WHERE Status__c NOT IN ('Resolved', 'Closed')
        ];

        // Score logic
        Decimal riskRatio = pipeline > 0 ? (report.revenueAtRisk / pipeline) : 0;
        report.score = Math.max(0, (100 - (riskRatio * 100))).setScale(1);
        
        if (report.score >= 90) { report.grade = 'A'; report.verdict = 'Protected'; }
        else if (report.score >= 75) { report.grade = 'B'; report.verdict = 'At Risk'; }
        else { report.grade = 'C'; report.verdict = 'Critical'; }

        return report;
    }
}

