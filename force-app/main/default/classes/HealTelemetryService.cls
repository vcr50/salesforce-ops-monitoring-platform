/**
 * HealTelemetryService
 * Closes the AI Decision telemetry loop by updating AI_Decision__c
 * records after heal execution completes.
 *
 * Also provides aggregated metrics (MTTR, success rate, auto-heal ratio)
 * for dashboard consumption by the portal and Copilot.
 *
 * @author  Tomcodex
 * @version 1.0 (Phase 6)
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class HealTelemetryService {

    // ── Inner Types ────────────────────────────────────────────────────────────
    public class HealMetrics {
        @AuraEnabled public Integer totalDecisions;
        @AuraEnabled public Integer autoExecuted;
        @AuraEnabled public Integer succeeded;
        @AuraEnabled public Integer failed;
        @AuraEnabled public Decimal autoHealRatio;
        @AuraEnabled public Decimal successRate;
        @AuraEnabled public Decimal avgConfidence;
    }

    // ── Telemetry Loop Closer ──────────────────────────────────────────────────

    /**
     * Called after an auto-heal completes. Updates the most recent
     * AI_Decision__c for the given incident to reflect actual outcome.
     *
     * @param incidentId  The healed Incident__c Id
     * @param success     Whether the heal action succeeded
     * @param actionTaken The action that was executed
     */
    public static void recordHealOutcome(Id incidentId, Boolean success, String actionTaken) {
        if (incidentId == null) return;

        SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
            'Id', 'Incident__c', 'Auto_Executed__c', 'Recommended_Action__c'
        });
        SecurityGate.requireUpdateAccess('AI_Decision__c', new Set<String>{
            'Auto_Executed__c', 'Execution_Result__c', 'Executed_Action__c', 'Executed_At__c'
        });

        // Find the most recent AI Decision for this incident
        List<AI_Decision__c> decisions = [
            SELECT Id, Auto_Executed__c, Recommended_Action__c
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (decisions.isEmpty()) return;

        AI_Decision__c decision = decisions[0];
        decision.Auto_Executed__c   = true;
        decision.Execution_Result__c = success ? 'Succeeded' : 'Failed';
        decision.Executed_Action__c  = actionTaken;
        decision.Executed_At__c      = System.now();

        try {
            update decision;
        } catch (Exception ex) {
            // Non-fatal — never let telemetry crash the pipeline
            SystemLogger.logMessage('HealTelemetryService', 'recordHealOutcome', 'ERROR',
                'Failed to update AI_Decision__c: ' + ex.getMessage());
        }
    }

    // ── Aggregated Metrics ─────────────────────────────────────────────────────

    /**
     * Returns aggregated heal metrics for the dashboard.
     * Cacheable for LWC consumption.
     */
    @AuraEnabled(cacheable=true)
    public static HealMetrics getHealMetrics() {
        SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
            'Id', 'Auto_Executed__c', 'Execution_Result__c', 'Confidence_Score__c'
        });

        HealMetrics metrics = new HealMetrics();

        List<AI_Decision__c> allDecisions = [
            SELECT Auto_Executed__c, Execution_Result__c, Confidence_Score__c
            FROM   AI_Decision__c
            WHERE  CreatedDate = LAST_N_DAYS:30
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];

        metrics.totalDecisions = allDecisions.size();
        metrics.autoExecuted   = 0;
        metrics.succeeded      = 0;
        metrics.failed         = 0;

        Decimal totalConfidence = 0;
        Integer confidenceCount = 0;

        for (AI_Decision__c d : allDecisions) {
            if (d.Auto_Executed__c == true) {
                metrics.autoExecuted++;
            }
            if (d.Execution_Result__c == 'Succeeded') {
                metrics.succeeded++;
            } else if (d.Execution_Result__c == 'Failed') {
                metrics.failed++;
            }
            if (d.Confidence_Score__c != null) {
                totalConfidence += d.Confidence_Score__c;
                confidenceCount++;
            }
        }

        metrics.autoHealRatio = metrics.totalDecisions > 0
            ? (Decimal.valueOf(metrics.autoExecuted) / Decimal.valueOf(metrics.totalDecisions) * 100).setScale(1)
            : 0;

        metrics.successRate = (metrics.succeeded + metrics.failed) > 0
            ? (Decimal.valueOf(metrics.succeeded) / Decimal.valueOf(metrics.succeeded + metrics.failed) * 100).setScale(1)
            : 0;

        metrics.avgConfidence = confidenceCount > 0
            ? (totalConfidence / confidenceCount).setScale(1)
            : 0;

        return metrics;
    }

    /**
     * Returns AI Decision history for a specific incident.
     * Used by the portal incident detail trust surface.
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Decision__c> getDecisionsForIncident(Id incidentId) {
        if (incidentId == null) return new List<AI_Decision__c>();

        SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
            'Id', 'Root_Cause__c', 'Recommended_Action__c', 'Confidence_Score__c',
            'Impact_Level__c', 'Auto_Executed__c', 'Execution_Result__c',
            'Executed_Action__c', 'Executed_At__c', 'Matched_Rule__c'
        });

        return [
            SELECT Id, Root_Cause__c, Recommended_Action__c, Confidence_Score__c,
                   Impact_Level__c, Auto_Executed__c, Execution_Result__c,
                   Executed_Action__c, Executed_At__c, Matched_Rule__c,
                   CreatedDate
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }
}

