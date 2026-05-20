/**
 * @description Wave 1 Connector for Razorpay — India's leading payment gateway.
 * Extends ConnectorBase to inherit Circuit Breaker, telemetry logging,
 * and automated Incident creation for Zentom orchestration.
 *
 * Monitors: Payment orders, capture status, refund health.
 * Named Credential: Razorpay_API (configured with Key ID + Key Secret via Basic Auth)
 */
public with sharing class RazorpayConnector extends ConnectorBase {

    private Id endpointId;
    private String resourcePath;

    /**
     * @description Default constructor monitors /orders endpoint.
     */
    public RazorpayConnector(Id endpointId) {
        this.endpointId   = endpointId;
        this.resourcePath = '/orders?count=10&status=created';
    }

    /**
     * @description Overloaded constructor for flexible resource monitoring.
     * Supports: /orders, /payments, /refunds
     */
    public RazorpayConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() {
        return this.endpointId;
    }

    /**
     * @description Builds the Razorpay API request using a Named Credential.
     * The Named Credential 'Razorpay_API' stores the Key ID and Key Secret
     * and handles the Basic Auth header automatically — no credentials in code.
     * Base URL: https://api.razorpay.com/v1
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Razorpay_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        return req;
    }

    /**
     * @description Processes the Razorpay API response.
     * Checks for Razorpay-specific error envelopes (error.code, error.description).
     * A non-2xx status is already handled by ConnectorBase, so we only
     * need to inspect application-level errors in the response body here.
     */
    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        
        if (String.isNotBlank(body)) {
            try {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
                
                // Razorpay wraps application errors in an 'error' key even on 200
                if (parsed.containsKey('error')) {
                    Map<String, Object> errorPayload = (Map<String, Object>) parsed.get('error');
                    String errorCode    = (String) errorPayload.get('code');
                    String errorDesc    = (String) errorPayload.get('description');
                    throw new ConnectorException(
                        'Razorpay Application Error [' + errorCode + ']: ' + errorDesc
                    );
                }

                // Log healthy response metrics
                Object count = parsed.get('count');
                System.debug('RazorpayConnector: Healthy response received. ' +
                    'Record count = ' + (count != null ? count : 'N/A') +
                    ' | HTTP ' + res.getStatusCode());

            } catch (JSONException je) {
                // Non-JSON response — log but don't fail (could be empty 204)
                System.debug('RazorpayConnector: Non-JSON body received — ' + je.getMessage());
            }
        }
    }
}

