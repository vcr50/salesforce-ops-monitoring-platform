/**
 * ExecutiveIntelligenceController
 * Phase 6 of the CTO Blueprint: Executive Intelligence & Business Metrics.
 *
 * Provides aggregated business-level metrics for the Executive Dashboard.
 * Answers questions like: Is revenue safe? What workflows threaten growth?
 *
 * @author SentinelFlow
 * @version 1.0
 */
public with sharing class ExecutiveIntelligenceController {

    public class ExecutiveMetrics {
        @AuraEnabled public Decimal totalRevenueAtRisk;
        @AuraEnabled public Integer businessSafetyScore;
        @AuraEnabled public Decimal revenueSavedByAI;
        @AuraEnabled public List<WorkflowRisk> topWorkflowRisks;
        @AuraEnabled public Integer activeCriticalIncidents;
    }

    public class WorkflowRisk {
        @AuraEnabled public String workflowStage;
        @AuraEnabled public Decimal aggregatedRisk;
        @AuraEnabled public Integer failureCount;
    }

    /**
     * Aggregates real-time business health and revenue exposure metrics.
     */
    @AuraEnabled(cacheable=true)
    public static ExecutiveMetrics getExecutiveMetrics() {
        ExecutiveMetrics metrics = new ExecutiveMetrics();
        metrics.totalRevenueAtRisk = 0;
        metrics.businessSafetyScore = 100;
        metrics.revenueSavedByAI = 0;
        metrics.activeCriticalIncidents = 0;
        metrics.topWorkflowRisks = new List<WorkflowRisk>();

        Id tenantId = TenantContext.getCurrentTenantId();

        // 1. Calculate Active Revenue Risk & Critical Incidents
        List<Incident__c> openIncidents = [
            SELECT Id, Severity__c, Revenue_at_Risk__c 
            FROM Incident__c 
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            AND Tenant__c = :tenantId
        ];

        for (Incident__c inc : openIncidents) {
            if (inc.Revenue_at_Risk__c != null) {
                metrics.totalRevenueAtRisk += inc.Revenue_at_Risk__c;
            }
            if (inc.Severity__c == 'Critical') {
                metrics.activeCriticalIncidents++;
            }
        }

        // 2. Calculate AI Prevention Metrics (Revenue Saved)
        List<Incident__c> healedIncidents = [
            SELECT Id, Revenue_at_Risk__c 
            FROM Incident__c 
            WHERE Auto_Heal_Status__c = 'Succeeded'
            AND CreatedDate = THIS_MONTH
            AND Tenant__c = :tenantId
        ];
        
        for (Incident__c inc : healedIncidents) {
            if (inc.Revenue_at_Risk__c != null) {
                metrics.revenueSavedByAI += inc.Revenue_at_Risk__c;
            }
        }

        // 3. Business Safety Score Algorithm
        // Start at 100. Deduct 15 for every Critical, 2 for every open incident.
        Integer penalty = (metrics.activeCriticalIncidents * 15) + (openIncidents.size() * 2);
        metrics.businessSafetyScore = Math.max(0, 100 - penalty);

        // 4. Workflow Risk Map (Aggregating Universal Events)
        AggregateResult[] riskAgg = [
            SELECT Workflow_Stage__c stage, SUM(Revenue_Risk__c) totalRisk, COUNT(Id) failures
            FROM Universal_Event__c
            WHERE Status__c = 'New'
            AND Tenant__c = :tenantId
            AND Workflow_Stage__c != null
            GROUP BY Workflow_Stage__c
            ORDER BY SUM(Revenue_Risk__c) DESC
            LIMIT 5
        ];

        for (AggregateResult ar : riskAgg) {
            WorkflowRisk wr = new WorkflowRisk();
            wr.workflowStage = (String) ar.get('stage');
            wr.aggregatedRisk = (Decimal) ar.get('totalRisk');
            wr.failureCount = (Integer) ar.get('failures');
            metrics.topWorkflowRisks.add(wr);
        }

        return metrics;
    }
}

