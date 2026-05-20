/**
 * @description Wave 2 Connector — HubSpot CRM.
 * Monitors CRM contacts sync and deal pipeline health.
 * Named Credential: HubSpot_API (Private App Token via Bearer auth)
 * Endpoint: https://api.hubapi.com
 */
public with sharing class HubSpotConnector extends ConnectorBase {

    private Id     endpointId;
    private String resourcePath;

    public HubSpotConnector(Id endpointId) {
        this.endpointId   = endpointId;
        this.resourcePath = '/crm/v3/objects/deals?limit=10&archived=false';
    }

    public HubSpotConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() { return this.endpointId; }

    /**
     * @description Uses Named Credential 'HubSpot_API'.
     * The Private App access token is stored in the credential — no code secrets.
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:HubSpot_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        if (String.isBlank(body)) return;
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            // HubSpot wraps errors in { status: 'error', message: '...', category: '...' }
            if ('error'.equalsIgnoreCase((String) parsed.get('status'))) {
                throw new ConnectorException(
                    'HubSpot Error [' + parsed.get('category') + ']: ' + parsed.get('message')
                );
            }
            Object total = parsed.get('total');
            System.debug('HubSpotConnector: OK — total records = ' + (total != null ? total : 'N/A'));
        } catch (JSONException je) {
            System.debug('HubSpotConnector: Non-JSON response — ' + je.getMessage());
        }
    }
}

