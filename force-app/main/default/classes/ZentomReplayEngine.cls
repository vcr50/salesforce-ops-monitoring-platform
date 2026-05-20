public with sharing class ZentomReplayEngine {
    /**
     * Records the AI decision lifecycle for auditability, trust, and evaluation.
     */
    public static void logDecision(
        Id incidentId, 
        ZentomContextEngine.ContextPacket context, 
        String prompt, 
        String response, 
        ZentomRiskEngine.RiskScore riskScore, 
        ZentomPolicyEngine.PolicyEvaluation policyEval, 
        String finalAction,
        Decimal confidenceScore
    ) {
        // Note: In a production environment, this would serialize the data and insert a Replay_Log__c record.
        System.debug('--- ZENTOM REPLAY LOG ---');
        System.debug('Incident: ' + incidentId);
        System.debug('Context ARR: ' + context.accountARR);
        System.debug('Risk Score: ' + riskScore.totalScore);
        System.debug('Confidence: ' + confidenceScore);
        System.debug('Policy Mode: ' + policyEval.mode.name());
        System.debug('Final Action: ' + finalAction);
        System.debug('-------------------------');

        try {
            SecurityGate.requireCreateAccess('Zentom_Replay_Log__c', new Set<String>{
                'Incident__c', 'Context_ARR__c', 'Risk_Score__c', 'Confidence_Score__c',
                'Policy_Mode__c', 'Proposed_Action__c', 'Replay_Payload__c'
            });

            Map<String, Object> payload = new Map<String, Object>{
                'prompt' => prompt,
                'response' => response,
                'context' => context,
                'risk' => riskScore,
                'policyReasoning' => policyEval.policyReasoning
            };

            Zentom_Replay_Log__c log = new Zentom_Replay_Log__c(
                Incident__c = incidentId,
                Context_ARR__c = context.accountARR,
                Risk_Score__c = riskScore.totalScore,
                Confidence_Score__c = confidenceScore,
                Policy_Mode__c = policyEval.mode.name(),
                Proposed_Action__c = finalAction,
                Replay_Payload__c = JSON.serialize(payload)
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to write Replay Log: ' + e.getMessage());
            // Do not throw; logging should not crash the orchestration pipeline.
        }
    }
}

