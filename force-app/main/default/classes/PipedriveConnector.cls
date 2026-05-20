/**
 * @description Wave 2 Connector — Pipedrive CRM.
 * Monitors deal pipeline sync and person/organisation data health.
 * Named Credential: Pipedrive_API (API Token via query param managed by NC)
 * Endpoint: https://api.pipedrive.com/v1
 */
public with sharing class PipedriveConnector extends ConnectorBase {

    private Id     endpointId;
    private String resourcePath;

    public PipedriveConnector(Id endpointId) {
        this.endpointId   = endpointId;
        this.resourcePath = '/deals?status=open&limit=10&start=0';
    }

    public PipedriveConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() { return this.endpointId; }

    /**
     * @description Uses Named Credential 'Pipedrive_API'.
     * API token is appended automatically by Salesforce Named Credential — no hardcoding.
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Pipedrive_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        if (String.isBlank(body)) return;
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            // Pipedrive returns { success: false, error: '...', error_info: '...' } on failure
            Boolean success = (Boolean) parsed.get('success');
            if (success != null && !success) {
                throw new ConnectorException(
                    'Pipedrive Error: ' + parsed.get('error') + ' — ' + parsed.get('error_info')
                );
            }
            Map<String, Object> pagination = (Map<String, Object>) parsed.get('additional_data');
            System.debug('Pipedrive Connector: OK | success=true | pagination=' + pagination);
        } catch (JSONException je) {
            System.debug('PipedriveConnector: Non-JSON response — ' + je.getMessage());
        }
    }
}

