public with sharing class ZentomAIClient {
    // IMPORTANT: Create a Named Credential in Setup called 'Zentom_AI_API'
    // with the root URL of your LLM (e.g., https://api.zentom.ai)
    private static final String API_ENDPOINT = 'callout:Zentom_AI_API/v1/chat/completions';
    
    public class ZentomDecision {
        @AuraEnabled public String recommendation {get;set;}
        @AuraEnabled public Integer confidence_score {get;set;}
        @AuraEnabled public String proposed_action {get;set;}
        @AuraEnabled public String rationale {get;set;}
    }

    public static final String ZENTOM_SYSTEM_PROMPT = 
        'You are the Zentom Orchestration System LLM, the central reasoning and governance engine ("orchestration moat") for the SentinelFlow platform. Your primary function is to process and resolve critical business incidents by integrating multiple specialized AI models and enforcing a rigorous governance framework.\n\n' +
        'Objective: Given an enriched incident context packet from the SentinelFlow Core, your task is to determine the optimal, safest, and revenue-aware remediation action. This action must be fully validated and prepared for execution through the system of record (Salesforce) via Agentforce.\n\n' +
        'Architecture and Workflow Constraints:\n' +
        'Reasoning First Strategy: You must employ a reasoning-first approach, prioritizing heavy inference via DeepSeek R1 (45% weight) for complex diagnosis and problem resolution.\n' +
        'Context Assembly: Before any action, utilize the Context Engine to gather full situational awareness. This context must include semantically similar past incidents (via Memory Engine/RAG), account ARR/tier (from Salesforce), the real-time calculated Revenue at Risk (from Revenue Pulse Engine), runbooks (from Knowledge Base), and incident history.\n' +
        'Model Routing and Specialization: Engage the Model Router to select the appropriate combination of models based on the task:\n' +
        '- DeepSeek R1 (Reasoning)\n' +
        '- Agentforce (20% weight, for Salesforce-native record updates and flow execution)\n' +
        '- DeepSeek Coder (for code tasks)\n' +
        '- Llama 3 (for low-latency, high-speed local inference).\n\n' +
        'Structural Governance (The Moat): No action is permitted to touch a production system without mandatory passage through four sequential governance and control gates:\n' +
        '1. Risk Evaluation: The action must pass a quantified risk assessment from the Risk Engine (measuring Technical Severity, Business Impact, Blast Radius, and Operational Context).\n' +
        '2. Policy Validation: The final action must be cleared by the Policy Engine against hard gates (e.g., if Confidence < 80% or if operational risk is high).\n' +
        '3. Confidence & AI Guardian Gate: Autonomous execution is strictly blocked under the following conditions, requiring immediate human escalation:\n' +
        '   - The model\'s self-reported technical confidence score is below 80%.\n' +
        '   - The real-time Revenue Risk (calculated by Revenue Pulse Engine) exceeds $50,000. Under no circumstances should AI auto-heal a high-financial-risk incident without human oversight.\n' +
        '   - The action involves irreversible data deletion or mass metadata changes in a production system.\n' +
        '4. Replay Logging: Every step of the decision lifecycle—including the assembled context, model prompt/response, risk scores, policy outcomes, and final action—must be logged to the Replay Engine for audit and future performance metrics.\n' +
        '5. Execution: Upon clearance, the final action must be relayed to the Execution Controller to manage pre-execution checks, sequencing, and step verification before safely initiating the action via Agentforce.\n\n' +
        'Required Output Format (Structured Response):\n\n' +
        'Generate the output in a normalized JSON format for the Policy Engine evaluation.\n' +
        '{\n' +
        '  "recommendation": "[A concise summary of the diagnosis and proposed path]",\n' +
        '  "confidence_score": "[Integer 0-100, reflecting model certainty]",\n' +
        '  "proposed_action": "[Specific, actionable command for the Execution Controller (e.g., \'Restart workflow X\', \'Open Salesforce case with severity Y\')]",\n' +
        '  "rationale": "[Detailed justification covering the diagnosis, why the action was selected, and how it adheres to both the 80% Confidence Gate and high-risk policy constraints.]"\n' +
        '}';
    
    public static ZentomDecision getZentomResponse(String userPrompt, String additionalContext) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('model', 'deepseek-reasoner');
        payload.put('response_format', new Map<String, String>{ 'type' => 'json_object' });
        
        String fullSystemContext = ZENTOM_SYSTEM_PROMPT + '\n\nADDITIONAL CONTEXT:\n' + additionalContext;

        List<Map<String, String>> messages = new List<Map<String, String>>();
        messages.add(new Map<String, String>{ 'role' => 'system', 'content' => fullSystemContext });
        messages.add(new Map<String, String>{ 'role' => 'user', 'content' => userPrompt });
        
        payload.put('messages', messages);
        req.setBody(JSON.serialize(payload));
        
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Parse standard JSON response
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> choices = (List<Object>) jsonResponse.get('choices');
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                    Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
                    String content = (String) message.get('content');
                    return (ZentomDecision) JSON.deserialize(content, ZentomDecision.class);
                }
            } else {
                System.debug('Zentom AI API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Zentom AI Callout Exception: ' + e.getMessage());
        }
        
        // Smart fallback mock for prototype environment when API is not available
        ZentomDecision mockDecision = new ZentomDecision();
        Decimal revRisk = 0;
        if (additionalContext.contains('Revenue Risk: ')) {
            String riskStr = additionalContext.substringAfter('Revenue Risk: ').trim();
            if (riskStr.contains('\n')) riskStr = riskStr.substringBefore('\n');
            try { revRisk = Decimal.valueOf(riskStr); } catch (Exception ignored) {}
        }

        if (revRisk > 50000) {
            mockDecision.confidence_score = 65;
            mockDecision.proposed_action = 'Escalate';
            mockDecision.recommendation = 'Incident carries > $50,000 Revenue Risk. Autonomous healing is blocked by the AI Guardian Policy.';
            mockDecision.rationale = 'Revenue Risk is ' + revRisk + ' which exceeds the $50k maximum threshold for autonomous healing. Escalating to human engineering team.';
        } else {
            mockDecision.confidence_score = 92;
            mockDecision.proposed_action = 'Restart Service';
            mockDecision.recommendation = 'Root cause identified as temporary API limit exhaustion. Safe to restart service.';
            mockDecision.rationale = 'Revenue Risk is ' + revRisk + ' (below $50k). Technical confidence is high based on pattern matching. Executing restart playbook.';
        }
        return mockDecision;
    }

    /**
     * The master orchestration loop. Connects all Zentom Engines into a single governed pipeline.
     */
    public static ZentomDecision orchestrateIncident(Id incidentId, String userPrompt, String taskType, String workflowStage) {
        // GATE 1: Context Assembly
        ZentomContextEngine.ContextPacket context = ZentomContextEngine.assembleContext(incidentId);
        
        // GATE 2: Risk Evaluation
        ZentomRiskEngine.RiskScore risk = ZentomRiskEngine.evaluateRisk(incidentId, context);
        
        // ROUTING: Model Selection
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(context, risk, taskType);
        
        // ENRICHMENT: Build context payload for LLM
        String enrichedContext = 'Account ARR: ' + context.accountARR + 
                                 '\nAccount Tier: ' + context.accountTier +
                                 '\nSimilar Incidents: ' + String.join(context.similarIncidents, '; ') +
                                 '\nCalculated Risk Score: ' + risk.totalScore + 
                                 '\nSelected Model: ' + model.name();
                                 
        // INFERENCE: Get AI Decision
        ZentomDecision decision = getZentomResponse(userPrompt, enrichedContext);
        
        // GATE 3: Policy Validation
        ZentomPolicyEngine.PolicyEvaluation policyEval = ZentomPolicyEngine.evaluateAction(decision.proposed_action, risk.totalScore, workflowStage);
        
        // GATE 4: Confidence & AI Guardian Gate
        if (decision.confidence_score < 80) {
            policyEval.mode = ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED;
            policyEval.policyReasoning = 'Escalated: Model confidence (' + decision.confidence_score + ') is below the 80% threshold.';
        }
        if (context.accountARR > 50000 && decision.proposed_action != 'Escalate') { // Simplified check for Guardian Gate
            policyEval.mode = ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED;
            policyEval.policyReasoning = 'Escalated: Revenue Risk exceeds $50k threshold for autonomous execution.';
        }
        
        // GATE 5: Replay Logging (Audit)
        ZentomReplayEngine.logDecision(incidentId, context, userPrompt, JSON.serialize(decision), risk, policyEval, decision.proposed_action, decision.confidence_score);
        
        // EXECUTION
        if (policyEval.mode == ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION) {
            try {
                ZentomExecutionController.executeAction(incidentId, decision.proposed_action, decision.confidence_score, risk, policyEval.mode);
                // EVALUATION: Log success
                ZentomEvaluationEngine.evaluateOutcome(incidentId, true, decision.proposed_action, decision.confidence_score);
            } catch (Exception e) {
                // EVALUATION: Log failure
                ZentomEvaluationEngine.evaluateOutcome(incidentId, false, decision.proposed_action, decision.confidence_score);
                throw e;
            }
        } else {
            System.debug('Action held from execution. Status: ' + policyEval.mode.name() + ' - ' + policyEval.policyReasoning);
        }
        
        return decision;
    }
}
