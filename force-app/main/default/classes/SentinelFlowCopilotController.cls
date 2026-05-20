@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class SentinelFlowCopilotController {
    @AuraEnabled
    public static String handleChatMessage(String userMessage) {
        String msgLower = userMessage.toLowerCase();
        
        if (msgLower.contains('analyze') || msgLower.contains('heal')) {
            // -- Security Gate: CRUD/FLS enforcement --
            SecurityGate.requireReadAccess('Incident__c', new Set<String>{
                'Id', 'Name', 'Description__c', 'Status__c'
            });

            // Find the most recent critical/high open incident
            List<Incident__c> incs = [SELECT Id, Name, Description__c FROM Incident__c WHERE Status__c IN ('Open', 'Investigating') ORDER BY CreatedDate DESC LIMIT 1];
            
            if (incs.isEmpty()) {
                return 'All clear — there are currently no open incidents to analyze. The system is in a healthy state.';
            }
            
            Incident__c target = incs[0];
            
            try {
                // -- Security Gate: CRUD/FLS enforcement for RAG Context --
                SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
                    'Root_Cause__c', 'Recommended_Action__c', 'Incident__c', 'Auto_Executed__c'
                });

                // Retrieve historical dataset for RAG (Retrieval-Augmented Generation) from the Memory Engine
                List<AI_Decision__c> pastDecisions = [
                    SELECT Root_Cause__c, Recommended_Action__c, Incident__r.Description__c
                    FROM AI_Decision__c
                    WHERE Auto_Executed__c = true
                    ORDER BY CreatedDate DESC
                    LIMIT 15
                ];
                
                String ragContext = '';
                if (!pastDecisions.isEmpty()) {
                    ragContext = '\n\nHISTORICAL LEARNING DATASET (Use this context to inform your suggestions):\n';
                    for (AI_Decision__c d : pastDecisions) {
                        ragContext += '- Past Incident: ' + (d.Incident__r.Description__c != null ? d.Incident__r.Description__c.abbreviate(100) : 'Unknown') + ' | Resolved Root Cause: ' + d.Root_Cause__c + ' | Successful Action: ' + d.Recommended_Action__c + '\n';
                    }
                }

                // Try Zentom AI first
                String systemPrompt = 'Summarize the following incident for an operations leader in one sentence and suggest a recovery action. Incident Context: ' + target.Description__c + ragContext;
                ZentomAIClient.ZentomDecision decision = ZentomAIClient.getZentomResponse(userMessage, systemPrompt);
                
                String response = '';
                
                if (decision != null) {
                    response = '[Zentom AI Analysis]\n' + 
                               'Diagnosis: ' + decision.recommendation + '\n' +
                               'Proposed Action: ' + decision.proposed_action + '\n' +
                               'Confidence: ' + decision.confidence_score + '%\n' +
                               'Rationale: ' + decision.rationale + '\n\n';
                } else {
                    // Fallback to internal metadata rules if Zentom callout fails
                    AIAnalysisService.AnalysisResult res = AIAnalysisService.analyseIncident(target.Id);
                    response = 'I analyzed the most recent incident (' + target.Description__c + ').\n\n' +
                               'Root Cause: ' + res.rootCause + '\n' +
                               'Recommended Action: ' + res.recommendedAction + '\n' +
                               'Confidence: ' + res.confidence + '%.\n\n';
                }
                                  
                if (msgLower.contains('heal')) {
                    SelfHealingEngine.HealResult healRes = SelfHealingEngine.healIncident(target.Id);
                    response += '\nI executed an auto-heal action. Result: ' + healRes.message;
                } else {
                    response += '\nWould you like me to execute an auto-heal action for this?';
                }
                
                return response;
            } catch (Exception e) {
                return 'I encountered an error while analyzing the incident: ' + e.getMessage();
            }
        }
        
        if (msgLower.contains('status') || msgLower.contains('summary')) {
            // -- Security Gate: CRUD/FLS enforcement --
            SecurityGate.requireAccessible('Incident__c');

            Integer critCount = [SELECT COUNT() FROM Incident__c WHERE Severity__c = 'Critical' AND Status__c = 'Open'];
            return 'Currently, there are ' + critCount + ' critical open incidents. The most critical issue is related to the Payment Gateway Timeout. Would you like me to analyze it?';
        }

        // ═══ Show Incidents / List ═══
        if (msgLower.contains('show incident') || msgLower.contains('list incident') || msgLower.contains('open incident') || msgLower.contains('all incident')) {
            SecurityGate.requireReadAccess('Incident__c', new Set<String>{
                'Id', 'Name', 'Severity__c', 'Status__c', 'Description__c'
            });

            List<Incident__c> incidents = [SELECT Name, Severity__c, Status__c, Description__c FROM Incident__c WHERE Status__c IN ('Open', 'Investigating') ORDER BY CreatedDate DESC LIMIT 8];

            if (incidents.isEmpty()) {
                return 'No open incidents found. All systems are operating normally.';
            }

            String response = 'Open Incidents (' + incidents.size() + '):\n\n';
            for (Incident__c inc : incidents) {
                String severity = inc.Severity__c != null ? inc.Severity__c : 'Unknown';
                String sevIcon = severity == 'Critical' ? '🔴' : severity == 'High' ? '🟠' : severity == 'Medium' ? '🟡' : '🟢';
                response += sevIcon + ' ' + inc.Name + ' [' + severity + '] — ' + (inc.Description__c != null ? inc.Description__c.abbreviate(60) : 'No description') + '\n';
            }
            response += '\nSay "analyze" to investigate the most recent one.';
            return response;
        }

        // ═══ Status / Summary / ERP ═══
        if (msgLower.contains('status') || msgLower.contains('summary') || msgLower.contains('erp') || msgLower.contains('sync') || msgLower.contains('health') || msgLower.contains('how') || msgLower.contains('overview')) {
            SecurityGate.requireAccessible('Incident__c');

            Integer critCount = [SELECT COUNT() FROM Incident__c WHERE Severity__c = 'Critical' AND Status__c = 'Open'];
            Integer totalOpen = [SELECT COUNT() FROM Incident__c WHERE Status__c IN ('Open', 'Investigating')];
            Integer resolvedToday = [SELECT COUNT() FROM Incident__c WHERE Status__c = 'Resolved' AND LastModifiedDate = TODAY];

            String healthStatus = critCount == 0 ? 'Healthy' : critCount <= 2 ? 'Degraded' : 'Critical';
            String healthIcon = critCount == 0 ? '🟢' : critCount <= 2 ? '🟡' : '🔴';

            return healthIcon + ' System Status: ' + healthStatus + '\n\n' +
                '• Critical incidents: ' + critCount + '\n' +
                '• Total open: ' + totalOpen + '\n' +
                '• Resolved today: ' + resolvedToday + '\n\n' +
                'Zentom Governance: All ' + (critCount > 0 ? 'critical actions require human approval via Gate 3.' : 'systems within autonomous threshold.') + '\n\n' +
                (critCount > 0 ? 'Would you like me to analyze the most critical incident?' : 'All clear — no action required.');
        }

        // ═══ Architecture / Zentom / How it works ═══
        if (msgLower.contains('architecture') || msgLower.contains('zentom') || msgLower.contains('engine') || msgLower.contains('how do you work') || msgLower.contains('governance') || msgLower.contains('model')) {
            return 'Zentom Orchestration System:\n\n' +
                'I operate through 8 specialized engines:\n' +
                '1. Context Engine — assembles situational awareness\n' +
                '2. Memory Engine — pattern recognition via embeddings\n' +
                '3. Policy Engine — governance rules enforcement\n' +
                '4. Risk Engine — 4-dimension danger quantification\n' +
                '5. Replay Engine — full decision audit trail\n' +
                '6. Evaluation Engine — model drift detection\n' +
                '7. Execution Controller — pre-production safety checks\n' +
                '8. Model Router — selects optimal AI model\n\n' +
                'AI Models: DeepSeek R1 (45%), Agentforce (20%), Llama 3 (10%), DeepSeek Coder (10%)\n\n' +
                '5 Governance Gates ensure no action reaches production without structural approval. Confidence < 80% or revenue risk > $50K triggers mandatory human review.\n\n' +
                'Switch to the Architecture tab above to see the full visual breakdown.';
        }

        // ═══ Training Data / Every Issue ═══
        if (msgLower.contains('train') || msgLower.contains('data') || msgLower.contains('every issue') || msgLower.contains('learned')) {
            SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
                'Root_Cause__c', 'Recommended_Action__c', 'Incident__c', 'Auto_Executed__c'
            });

            List<AI_Decision__c> allDecisions = [
                SELECT Root_Cause__c, Recommended_Action__c, Incident__r.Description__c
                FROM AI_Decision__c
                WHERE Auto_Executed__c = true
                ORDER BY CreatedDate DESC
                LIMIT 15
            ];

            if (allDecisions.isEmpty()) {
                return 'The Memory Engine dataset is currently empty. As incidents are resolved, I will automatically train on the outcomes.';
            }

            String response = '🧠 **Zentom Memory Engine (Trained Data)**\n\n' +
                              'I have continually trained on past auto-executed decisions from every resolved issue to improve my accuracy. Here is a snapshot of my learned dataset:\n\n';
            
            Integer counter = 1;
            for (AI_Decision__c d : allDecisions) {
                String descr = d.Incident__r.Description__c != null ? d.Incident__r.Description__c.abbreviate(40) : 'Unknown incident';
                response += counter + '. **Issue:** ' + descr + '\n   **Learned Root Cause:** ' + d.Root_Cause__c + '\n   **Validated Action:** ' + d.Recommended_Action__c + '\n\n';
                counter++;
            }

            response += 'This exact dataset is fed dynamically via RAG into DeepSeek R1 every time you ask me to "Analyze the latest incident", ensuring I don\'t repeat past mistakes.';
            return response;
        }

        // ═══ Thanks / Goodbye ═══
        if (msgLower.contains('thank') || msgLower.contains('thanks') || msgLower.contains('bye') || msgLower.contains('goodbye')) {
            return 'You\'re welcome! I\'m always monitoring your Salesforce environment through the Zentom engines. Come back anytime you need incident analysis, revenue risk assessment, or system health checks. Stay safe! 🛡️';
        }

        // ═══ Salesforce Knowledge / General Questions ═══
        if (msgLower.startsWith('how') || msgLower.startsWith('what') || msgLower.startsWith('why') || msgLower.startsWith('can you') || msgLower.startsWith('explain') || msgLower.contains('salesforce')) {
            try {
                String systemPrompt = 'You are Zentom Hybrid AI, an expert Salesforce architect and Agentforce Copilot. Answer the user\'s question concisely, focusing on Salesforce best practices, LWC, Apex, Flow, or Agentforce capabilities. Keep the response under 4 sentences. If the question is unclear, ask for clarification.';
                
                // Call Zentom AI for a general knowledge response
                ZentomAIClient.ZentomDecision decision = ZentomAIClient.getZentomResponse(userMessage, systemPrompt);
                
                if (decision != null && decision.rationale != null) {
                    return '[Zentom Knowledge Base]\n' + decision.rationale;
                }
            } catch (Exception e) {
                System.debug('Zentom Knowledge Callout Failed: ' + e.getMessage());
            }
        }

        // ═══ Fallback — more helpful ═══
        return 'I didn\'t quite catch that. Here are some things you can ask me:\n\n' +
            '• "What\'s the system status?" — Live health check\n' +
            '• "Analyze the latest incident" — AI-powered diagnosis\n' +
            '• "Show revenue at risk" — Financial exposure\n' +
            '• "Show open incidents" — Incident queue\n' +
            '• "Heal critical incidents" — Auto-remediation\n' +
            '• "Tell me about Zentom" — Architecture overview\n' +
            '• Or ask me a general Salesforce question!\n\n' +
            'Or try one of the quick actions below.';
    }
}

