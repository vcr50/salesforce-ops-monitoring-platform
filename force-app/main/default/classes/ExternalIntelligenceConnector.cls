/**
 * Base class for connectors that bring third-party reliability or business
 * intelligence into SentinelFlow through Named Credentials.
 */
public abstract with sharing class ExternalIntelligenceConnector extends ConnectorBase {

    // Abstract methods required by subclasses of ExternalIntelligenceConnector
    public abstract String getConnectorName();
    public abstract String getNamedCredential();
    public abstract String mapRevenueImpact(Integration_Log__c logRecord);

    // Stubs for ConnectorBase's abstract methods so subclasses don't have to implement them if not needed
    protected override Id getEndpointId() {
        return null;
    }
    protected override HttpRequest buildRequest() {
        return null;
    }
    protected override void processResponse(HttpResponse response) {
        // stub
    }

    protected HttpResponse sendGet(String resource) {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint('callout:' + getNamedCredential() + normalizeResource(resource));
        request.setTimeout(20000);
        return new Http().send(request);
    }

    protected String normalizeResource(String resource) {
        if (String.isBlank(resource)) {
            return '/';
        }
        return resource.startsWith('/') ? resource : '/' + resource;
    }

    public HttpResponse fetchData(String resource) {
        return sendGet(resource);
    }

    public Integration_Log__c normalizeResponse(HttpResponse response) {
        Integration_Log__c logRecord = new Integration_Log__c();
        logRecord.API_Name__c = getConnectorName();
        if (response != null) {
            logRecord.Response_Code__c = response.getStatusCode();
        }
        logRecord.Status__c = response != null && response.getStatusCode() >= 200 && response.getStatusCode() < 300
            ? 'Success'
            : 'Failed';
        if (logRecord.Status__c == 'Failed' && response != null) {
            logRecord.Error_Message__c = response.getStatus() + ': ' + response.getBody();
        }
        return logRecord;
    }

    /**
     * Executes a monitored callout with full Circuit Breaker, Telemetry, and Incident auto-creation.
     */
    public Integration_Log__c executeMonitoredCall(Id endpointId, String resource) {
        // 1. Circuit Breaker Check
        if (endpointId != null && CircuitBreaker.isCircuitOpen(endpointId)) {
            throw new ConnectorBase.ConnectorException('Circuit Breaker is OPEN. Request blocked to prevent cascading failures.');
        }

        Long startTime = System.currentTimeMillis();
        HttpResponse res = null;
        String errMsg = null;
        try {
            res = fetchData(resource);
            if (res != null && (res.getStatusCode() < 200 || res.getStatusCode() >= 300)) {
                errMsg = 'HTTP Error ' + res.getStatusCode() + ': ' + res.getBody();
            }
        } catch (Exception e) {
            errMsg = e.getMessage();
        }
        Long duration = System.currentTimeMillis() - startTime;

        Integration_Log__c logRecord = normalizeResponse(res);
        logRecord.Integration_Endpoint__c = endpointId;
        logRecord.Response_Time__c = duration;
        if (errMsg != null) {
            logRecord.Status__c = 'Failed';
            logRecord.Error_Message__c = errMsg;
        }

        // Insert log record (Security gate checked)
        SecurityGate.requireCreateAccess('Integration_Log__c', new Set<String>{
            'Integration_Endpoint__c', 'Status__c', 'Error_Message__c', 'Response_Code__c', 'Response_Time__c', 'API_Name__c'
        });
        insert as user logRecord;

        // Circuit Breaker & Incident updates
        if (endpointId != null) {
            if (logRecord.Status__c == 'Success') {
                CircuitBreaker.recordSuccess(endpointId);
            } else {
                CircuitBreaker.recordFailure(endpointId);
                // Create Incident
                SecurityGate.requireCreateAccess('Incident__c', new Set<String>{
                    'Integration_Endpoint__c', 'Integration_Log__c', 'Severity__c', 'Status__c', 'Description__c', 'Self_Heal_Attempted__c'
                });
                Incident__c inc = new Incident__c(
                    Integration_Endpoint__c = endpointId,
                    Integration_Log__c = logRecord.Id,
                    Severity__c = 'High',
                    Status__c = 'Open',
                    Description__c = 'Connector Failure: ' + (logRecord.Error_Message__c != null ? logRecord.Error_Message__c : 'Unknown error'),
                    Self_Heal_Attempted__c = false
                );
                insert as user inc;
            }
        }

        return logRecord;
    }
}

