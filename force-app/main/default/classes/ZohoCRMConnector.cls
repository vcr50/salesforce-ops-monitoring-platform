/**
 * @description Wave 2 Connector — Zoho CRM.
 * Monitors leads, deals, and contact sync health.
 * Named Credential: ZohoCRM_API (OAuth 2.0 managed by Salesforce Auth Provider)
 * Endpoint: https://www.zohoapis.com/crm/v6
 */
public with sharing class ZohoCRMConnector extends ConnectorBase {

    private Id     endpointId;
    private String resourcePath;

    public ZohoCRMConnector(Id endpointId) {
        this.endpointId   = endpointId;
        this.resourcePath = '/Deals?fields=Deal_Name,Stage,Amount&page=1&per_page=10';
    }

    public ZohoCRMConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() { return this.endpointId; }

    /**
     * @description Uses Named Credential 'ZohoCRM_API' with OAuth 2.0.
     * Salesforce handles token refresh automatically — zero credentials in code.
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ZohoCRM_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        if (String.isBlank(body)) return;
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            // Zoho wraps errors in { code: 'INVALID_TOKEN', details: {}, message: '...', status: 'error' }
            if (parsed.containsKey('code') && !'SUCCESS'.equalsIgnoreCase((String) parsed.get('status'))) {
                throw new ConnectorException(
                    'Zoho CRM Error [' + parsed.get('code') + ']: ' + parsed.get('message')
                );
            }
            List<Object> data = (List<Object>) parsed.get('data');
            System.debug('ZohoCRMConnector: OK — records = ' + (data != null ? data.size() : 0));
        } catch (JSONException je) {
            System.debug('ZohoCRMConnector: Non-JSON response — ' + je.getMessage());
        }
    }
}

