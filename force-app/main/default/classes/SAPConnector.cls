public with sharing class SAPConnector extends ConnectorBase {
    private Id endpointId;
    
    public SAPConnector(Id endpointId) {
        this.endpointId = endpointId;
    }

    protected override Id getEndpointId() {
        return this.endpointId;
    }

    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        // In a real scenario, this would use a Named Credential: 'callout:SAP_S4HANA/sap/opu/odata/sap/API_BUSINESS_PARTNER'
        req.setEndpoint('callout:SAP_S4HANA/sap/opu/odata/sap/API_BUSINESS_PARTNER');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        System.debug('SAPConnector: Successfully processed response with status ' + res.getStatusCode());
        // Handle SAP-specific response validation and parsing (e.g. OData error formats)
    }
}

