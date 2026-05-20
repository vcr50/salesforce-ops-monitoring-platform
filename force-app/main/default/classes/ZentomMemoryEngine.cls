/**
 * ZentomMemoryEngine
 * Phase 4 of the CTO Blueprint: Operational Memory System.
 * 
 * Retrieves successful historical AI decisions and incident resolutions
 * to provide few-shot learning examples and historical context to the AI.
 * This forms the core "moat" by turning past incidents into reusable intelligence.
 *
 * @author SentinelFlow
 */
public with sharing class ZentomMemoryEngine {
    
    public class HistoricalContext {
        public String previousResolution;
        public Boolean wasSuccessful;
        public Decimal confidenceScore;
        public String humanOverrideInfo;
    }

    /**
     * Searches the AI_Decision__c database for past similar incidents and extracts
     * the proven resolution path.
     */
    public static HistoricalContext retrieveMemoryForIncident(String workflowStage, String errorSignature) {
        HistoricalContext context = new HistoricalContext();
        context.wasSuccessful = false;
        
        Id tenantId = TenantContext.getCurrentTenantId();

        // Ensure security access before querying memory
        SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
            'Root_Cause__c', 'Executed_Action__c', 'Was_Accepted__c', 'Confidence_Score__c'
        });

        // Search for past decisions that were accepted and successful
        List<AI_Decision__c> pastDecisions = [
            SELECT Root_Cause__c, Executed_Action__c, Confidence_Score__c, Reasoning__c, Was_Accepted__c
            FROM AI_Decision__c
            WHERE Tenant__c = :tenantId
            AND Was_Accepted__c = true
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        AI_Decision__c bestMatch = null;
        for (AI_Decision__c decision : pastDecisions) {
            if (decision.Root_Cause__c != null && decision.Root_Cause__c.containsIgnoreCase(errorSignature)) {
                bestMatch = decision;
                break;
            }
        }

        if (bestMatch != null) {
            context.previousResolution = bestMatch.Executed_Action__c;
            context.wasSuccessful = true;
            context.confidenceScore = bestMatch.Confidence_Score__c;
            context.humanOverrideInfo = bestMatch.Reasoning__c;
        } else {
            context.previousResolution = 'No historical memory found for this error signature.';
        }

        return context;
    }
}

