public with sharing class CircuitBreaker {
    
    public static final Integer DEFAULT_THRESHOLD = 5;

    public class CircuitException extends Exception {}

    /**
     * Increments the failure count for an endpoint and trips the circuit if it exceeds the threshold.
     * Prevents cascading failures and API limit breaches.
     */
    public static void recordFailure(Id endpointId) {
        if (endpointId == null) return;
        
        SecurityGate.requireReadAccess('Integration_Endpoint__c', new Set<String>{'Id', 'Circuit_Status__c', 'Failure_Count__c', 'Max_Retries__c'});
        SecurityGate.requireUpdateable('Integration_Endpoint__c');

        Integration_Endpoint__c endpoint = [SELECT Id, Circuit_Status__c, Failure_Count__c, Max_Retries__c FROM Integration_Endpoint__c WHERE Id = :endpointId FOR UPDATE];
        
        Decimal failCount = endpoint.Failure_Count__c != null ? endpoint.Failure_Count__c : 0;
        failCount++;
        
        Decimal threshold = endpoint.Max_Retries__c != null ? endpoint.Max_Retries__c : DEFAULT_THRESHOLD;
        
        if (failCount >= threshold && endpoint.Circuit_Status__c != 'Open') {
            endpoint.Circuit_Status__c = 'Open';
            AuditTrailService.log(endpoint.Id, 'Integration_Endpoint__c', 'Circuit Tripped', 'Closed', 'Open due to ' + failCount + ' failures');
        }
        
        endpoint.Failure_Count__c = failCount;
        update as user endpoint;
    }
    
    /**
     * Checks if the circuit is currently open (tripped). If open, requests should be blocked.
     */
    public static Boolean isCircuitOpen(Id endpointId) {
        if (endpointId == null) return false;
        
        SecurityGate.requireReadAccess('Integration_Endpoint__c', new Set<String>{'Id', 'Circuit_Status__c'});
        
        Integration_Endpoint__c endpoint = [SELECT Id, Circuit_Status__c FROM Integration_Endpoint__c WHERE Id = :endpointId];
        return endpoint.Circuit_Status__c == 'Open';
    }
    
    /**
     * Records a successful request, resetting the failure count and closing the circuit if it was open.
     */
    public static void recordSuccess(Id endpointId) {
        if (endpointId == null) return;
        
        SecurityGate.requireReadAccess('Integration_Endpoint__c', new Set<String>{'Id', 'Circuit_Status__c', 'Failure_Count__c'});
        SecurityGate.requireUpdateable('Integration_Endpoint__c');

        Integration_Endpoint__c endpoint = [SELECT Id, Circuit_Status__c, Failure_Count__c FROM Integration_Endpoint__c WHERE Id = :endpointId FOR UPDATE];
        
        if (endpoint.Circuit_Status__c != 'Closed' || endpoint.Failure_Count__c > 0) {
            endpoint.Circuit_Status__c = 'Closed';
            endpoint.Failure_Count__c = 0;
            update as user endpoint;
            
            AuditTrailService.log(endpoint.Id, 'Integration_Endpoint__c', 'Circuit Reset', 'Open', 'Closed after success');
        }
    }
}

