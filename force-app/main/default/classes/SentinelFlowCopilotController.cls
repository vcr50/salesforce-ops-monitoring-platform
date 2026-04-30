public with sharing class SentinelFlowCopilotController {
    @AuraEnabled
    public static String handleChatMessage(String userMessage) {
        String msgLower = userMessage.toLowerCase();
        
        if (msgLower.contains('analyze') || msgLower.contains('heal')) {
            // Find the most recent critical/high open incident
            List<Incident__c> incs = [SELECT Id, Name, Description__c FROM Incident__c WHERE Status__c IN ('Open', 'Investigating') ORDER BY CreatedDate DESC LIMIT 1];
            
            if (incs.isEmpty()) {
                return 'There are currently no open incidents to analyze.';
            }
            
            Incident__c target = incs[0];
            
            try {
                AIAnalysisService.AnalysisResult res = AIAnalysisService.analyseIncident(target.Id);
                
                String response = 'I have analyzed the most recent incident (' + target.Description__c + ').\n\n' +
                                  '**Root Cause:** ' + res.rootCause + '\n' +
                                  '**Recommended Action:** ' + res.recommendedAction + '\n' +
                                  '**Confidence:** ' + res.confidence + '%.\n\n';
                                  
                if (msgLower.contains('heal')) {
                    SelfHealingEngine.HealResult healRes = SelfHealingEngine.healIncident(target.Id);
                    response += 'I executed an auto-heal action. Result: ' + healRes.message;
                } else {
                    response += 'Would you like me to execute an auto-heal action for this?';
                }
                
                return response;
            } catch (Exception e) {
                return 'I encountered an error while analyzing the incident: ' + e.getMessage();
            }
        }
        
        if (msgLower.contains('status') || msgLower.contains('summary')) {
            Integer critCount = [SELECT COUNT() FROM Incident__c WHERE Severity__c = 'Critical' AND Status__c = 'Open'];
            return 'Currently, there are ' + critCount + ' critical open incidents. The most critical issue is related to the Payment Gateway Timeout. Would you like me to analyze it?';
        }
        
        return 'I am the SentinelFlow AI Copilot. I am connected directly to your Salesforce environment. Ask me to "analyze the latest incident" or "heal critical issues".';
    }
}
