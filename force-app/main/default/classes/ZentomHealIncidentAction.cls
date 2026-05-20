public with sharing class ZentomHealIncidentAction {
    @InvocableMethod(label='Execute Auto-Heal' description='Executes the SentinelFlow Self-Healing Engine for a specific incident.' category='SentinelFlow')
    public static List<HealResultOutput> executeAutoHeal(List<HealRequest> requests) {
        List<HealResultOutput> outputs = new List<HealResultOutput>();
        
        for (HealRequest req : requests) {
            HealResultOutput output = new HealResultOutput();
            try {
                SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(req.incidentId);
                output.isSuccess = result.success;
                output.message = result.message;
                output.actionTaken = result.actionTaken;
            } catch (Exception e) {
                output.isSuccess = false;
                output.message = 'Auto-Heal failed: ' + e.getMessage();
                output.actionTaken = 'Failed';
            }
            outputs.add(output);
        }
        
        return outputs;
    }
    
    public class HealRequest {
        @InvocableVariable(label='Incident ID' description='The Salesforce ID of the Incident__c record to heal.' required=true)
        public Id incidentId;
    }
    
    public class HealResultOutput {
        @InvocableVariable(label='Is Success' description='True if the healing action succeeded')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Detailed message from the healing engine')
        public String message;
        
        @InvocableVariable(label='Action Taken' description='The specific action that was executed')
        public String actionTaken;
    }
}

