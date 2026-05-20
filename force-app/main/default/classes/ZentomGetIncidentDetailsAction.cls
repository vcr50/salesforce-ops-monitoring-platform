public with sharing class ZentomGetIncidentDetailsAction {
    
    @InvocableMethod(label='Get Deep Incident Details' description='Retrieves deep technical details, logs, and stack traces for a specific SentinelFlow incident to allow Zentom AI to perform root cause analysis.' category='SentinelFlow')
    public static List<IncidentDetailResult> getIncidentDetails(List<IncidentDetailRequest> requests) {
        List<IncidentDetailResult> results = new List<IncidentDetailResult>();
        
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        
        Set<Id> incidentIds = new Set<Id>();
        for (IncidentDetailRequest req : requests) {
            if (req.incidentId != null) {
                incidentIds.add(req.incidentId);
            }
        }
        
        // Security Gate check
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{'Id', 'Name', 'Description__c', 'Error_Type__c', 'Integration_Log__c', 'Integration_Endpoint__c', 'Revenue_at_Risk__c'});
        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{'Id', 'API_Name__c', 'Error_Message__c', 'Status__c'});

        Map<Id, Incident__c> incidents = new Map<Id, Incident__c>([
            SELECT Id, Name, Description__c, Error_Type__c, Revenue_at_Risk__c,
                   Integration_Log__r.API_Name__c, 
                   Integration_Log__r.Error_Message__c,
                   Integration_Log__r.Status__c,
                   Integration_Endpoint__r.Name
            FROM Incident__c 
            WHERE Id IN :incidentIds
        ]);
        
        for (IncidentDetailRequest req : requests) {
            IncidentDetailResult res = new IncidentDetailResult();
            Incident__c inc = incidents.get(req.incidentId);
            
            if (inc != null) {
                res.incidentName = inc.Name;
                res.errorType = inc.Error_Type__c;
                res.description = inc.Description__c;
                
                if (inc.Integration_Log__r != null) {
                    res.technicalLog = 'API Name: ' + inc.Integration_Log__r.API_Name__c + '\n' +
                                       'Status: ' + inc.Integration_Log__r.Status__c + '\n' +
                                       'Error Message: ' + inc.Integration_Log__r.Error_Message__c;
                } else {
                    res.technicalLog = 'No direct integration log attached to this incident. Rely on the description and error type.';
                }

                // Inject Revenue Pulse data for AI Guardian Gate
                if (inc.Revenue_at_Risk__c != null) {
                    res.revenueRisk = inc.Revenue_at_Risk__c;
                    res.technicalLog += '\n\n--- AI GUARDIAN CONTEXT ---\n' +
                                        'REVENUE AT RISK: $' + inc.Revenue_at_Risk__c + '\n' +
                                        'If this value > $50000, autonomous execution MUST be blocked.';
                }
            }
            results.add(res);
        }
        
        return results;
    }
    
    public class IncidentDetailRequest {
        @InvocableVariable(label='Incident ID' description='The Salesforce ID of the Incident__c' required=true)
        public Id incidentId;
    }
    
    public class IncidentDetailResult {
        @InvocableVariable(label='Incident Name' description='The Name of the incident')
        public String incidentName;
        
        @InvocableVariable(label='Error Type' description='The classification of the error')
        public String errorType;
        
        @InvocableVariable(label='Description' description='High level description')
        public String description;
        
        @InvocableVariable(label='Technical Log Payload' description='The raw technical data, stack trace, and JSON payloads')
        public String technicalLog;
        
        @InvocableVariable(label='Revenue at Risk' description='The financial risk calculated by Revenue Pulse Engine')
        public Decimal revenueRisk;
    }
}

