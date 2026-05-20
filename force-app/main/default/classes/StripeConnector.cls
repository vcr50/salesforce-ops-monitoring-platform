public with sharing class StripeConnector extends ConnectorBase {

    private Id endpointId;
    
    // Constructor allows passing the endpoint ID from config
    public StripeConnector(Id endpointId) {
        this.endpointId = endpointId;
    }

    protected override Id getEndpointId() {
        return this.endpointId;
    }

    protected override HttpRequest buildRequest() {
        // Build the specific request for Stripe
        // In a real scenario, this would use Named Credentials: 'callout:Stripe_API/v1/charges'
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Stripe_API/v1/charges');
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        // Handle Stripe-specific parsing logic here
        // The base class already checks for HTTP status errors (500, etc.)
        // We can parse JSON to look for Stripe-specific application errors
        
        System.debug('StripeConnector: Successfully processed response with status ' + res.getStatusCode());
        
        // Example logic:
        /*
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (body.containsKey('error')) {
            Map<String, Object> err = (Map<String, Object>) body.get('error');
            throw new ConnectorException('Stripe API Error: ' + err.get('message'));
        }
        */
    }
}

