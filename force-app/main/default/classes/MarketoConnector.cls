/**
 * @description Wave 2 Connector — Marketo Engage.
 * Monitors lead database sync, campaign execution health.
 * Named Credential: Marketo_API (OAuth 2.0 Client Credentials flow)
 * Endpoint: https://{munchkin-id}.mktorest.com/rest/v1
 */
public with sharing class MarketoConnector extends ConnectorBase {

    private Id     endpointId;
    private String resourcePath;

    public MarketoConnector(Id endpointId) {
        this.endpointId   = endpointId;
        this.resourcePath = '/leads.json?filterType=id&filterValues=1,2,3';
    }

    public MarketoConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() { return this.endpointId; }

    /**
     * @description Uses Named Credential 'Marketo_API' for OAuth 2.0 token management.
     * Marketo returns HTTP 200 even on error — errors are embedded in the response body.
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Marketo_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        if (String.isBlank(body)) return;
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            // Marketo always returns HTTP 200 — errors in { success: false, errors: [...] }
            Boolean success = (Boolean) parsed.get('success');
            if (success != null && !success) {
                List<Object> errors = (List<Object>) parsed.get('errors');
                String errMsg = errors != null && !errors.isEmpty()
                    ? JSON.serialize(errors[0])
                    : 'Unknown Marketo error';
                throw new ConnectorException('Marketo Error: ' + errMsg);
            }
            List<Object> result = (List<Object>) parsed.get('result');
            System.debug('MarketoConnector: OK — leads returned = ' + (result != null ? result.size() : 0));
        } catch (JSONException je) {
            System.debug('MarketoConnector: Non-JSON response — ' + je.getMessage());
        }
    }
}

