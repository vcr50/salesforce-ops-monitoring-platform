public abstract with sharing class ConnectorBase {

    public class ConnectorException extends Exception {}

    /**
     * @description Provides the ID of the Integration_Endpoint__c record.
     */
    protected abstract Id getEndpointId();

    /**
     * @description Builds the specific HttpRequest for this connector.
     */
    protected abstract HttpRequest buildRequest();

    /**
     * @description Hook for concrete classes to process the response.
     * Should throw an Exception if the response indicates failure (e.g., HTTP 500 or application error).
     */
    protected abstract void processResponse(HttpResponse response);

    /**
     * @description Executes the HTTP callout wrapped with Circuit Breaker, telemetry, and logging.
     * @return The HttpResponse object if successful.
     */
    public HttpResponse executeMonitoredCall() {
        Id endpointId = getEndpointId();

        // 1. Circuit Breaker Check
        if (CircuitBreaker.isCircuitOpen(endpointId)) {
            // Log circuit open state as an incident? Not needed here, CircuitBreaker already logs.
            throw new ConnectorException('Circuit Breaker is OPEN. Request blocked to prevent cascading failures.');
        }

        HttpRequest req = buildRequest();
        Http http = new Http();
        
        Long startTime = System.currentTimeMillis();
        HttpResponse res = null;
        
        try {
            // 2. Perform HTTP Callout
            res = http.send(req);
            Long duration = System.currentTimeMillis() - startTime;
            
            // Allow child to validate response (e.g. check for non-2xx status codes)
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new ConnectorException('HTTP Error ' + res.getStatusCode() + ': ' + res.getBody());
            }

            processResponse(res); 

            // 3. Log Success
            logIntegration(endpointId, 'Success', null, res.getStatusCode(), duration);
            CircuitBreaker.recordSuccess(endpointId);
            
            return res;
            
        } catch (Exception e) {
            Long duration = System.currentTimeMillis() - startTime;
            Integer statusCode = (res != null) ? res.getStatusCode() : 500;
            
            // 4. Log Failure & Trip Circuit
            Id logId = logIntegration(endpointId, 'Failed', e.getMessage(), statusCode, duration);
            CircuitBreaker.recordFailure(endpointId);
            
            // 5. Trigger Incident Auto-Creation for Zentom Orchestration
            // (Handled automatically by IntegrationLogTrigger)
            
            throw new ConnectorException('Connector call failed: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates a telemetry log record for the API call.
     */
    private Id logIntegration(Id endpointId, String status, String errorMsg, Integer statusCode, Long duration) {
        SecurityGate.requireCreateAccess('Integration_Log__c', new Set<String>{
            'Integration_Endpoint__c', 'Status__c', 'Error_Message__c', 'Response_Code__c', 'Response_Time__c'
        });
        
        Integration_Log__c log = new Integration_Log__c(
            Integration_Endpoint__c = endpointId,
            Status__c               = status,
            Error_Message__c        = (errorMsg != null && errorMsg.length() > 255) ? errorMsg.substring(0, 255) : errorMsg,
            Response_Code__c        = statusCode,
            Response_Time__c        = duration
        );
        insert as user log;
        return log.Id;
    }
}