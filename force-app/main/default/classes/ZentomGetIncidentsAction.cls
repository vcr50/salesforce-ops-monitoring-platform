public with sharing class ZentomGetIncidentsAction {
    @InvocableMethod(label='Get Open Incidents' description='Retrieves a list of open, unresolved incidents from SentinelFlow for Zentom AI to analyze.' category='SentinelFlow')
    public static List<IncidentResult> getOpenIncidents(List<IncidentRequest> requests) {
        String severityFilter = (requests != null && !requests.isEmpty() && requests[0].severity != null) ? requests[0].severity : null;
        
        String query = 'SELECT Id, Name, Severity__c, Status__c, Description__c, Error_Type__c, Root_Cause__c, Recommended_Action__c, AI_Impact_Level__c, Revenue_at_Risk__c FROM Incident__c WHERE Status__c != \'Resolved\' AND Status__c != \'Closed\'';
        
        if (String.isNotBlank(severityFilter)) {
            query += ' AND Severity__c = :severityFilter';
        }
        
        query += ' ORDER BY CreatedDate DESC LIMIT 10';
        
        List<Incident__c> openIncidents = Database.query(query);
        
        IncidentResult result = new IncidentResult();
        result.incidents = openIncidents;
        
        return new List<IncidentResult>{ result };
    }
    
    public class IncidentRequest {
        @InvocableVariable(label='Severity Filter' description='Optional filter by severity (e.g. Critical, High)')
        public String severity;
    }
    
    public class IncidentResult {
        @InvocableVariable(label='Open Incidents' description='List of open incidents')
        public List<Incident__c> incidents;
    }
}

