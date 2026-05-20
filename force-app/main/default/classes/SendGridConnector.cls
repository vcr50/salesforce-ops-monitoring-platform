/**
 * @description Wave 2 Connector — SendGrid Email.
 * Monitors transactional email delivery health, bounce/spam rates.
 * Named Credential: SendGrid_API (Bearer API Key)
 * Endpoint: https://api.sendgrid.com/v3
 */
public with sharing class SendGridConnector extends ConnectorBase {

    private Id     endpointId;
    private String resourcePath;

    public SendGridConnector(Id endpointId) {
        this.endpointId   = endpointId;
        // Monitor global suppression bounces — high bounce rate = revenue risk
        this.resourcePath = '/suppression/bounces?start_time=0&end_time=9999999999&limit=10&offset=0';
    }

    public SendGridConnector(Id endpointId, String resourcePath) {
        this.endpointId   = endpointId;
        this.resourcePath = resourcePath;
    }

    protected override Id getEndpointId() { return this.endpointId; }

    /**
     * @description Uses Named Credential 'SendGrid_API' with Bearer token.
     * API key is stored in the credential — never in code.
     */
    protected override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SendGrid_API' + this.resourcePath);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    protected override void processResponse(HttpResponse res) {
        String body = res.getBody();
        if (String.isBlank(body)) return;
        try {
            Object parsed = JSON.deserializeUntyped(body);

            // SendGrid errors come as { errors: [{ message: '...' }] }
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> parsedMap = (Map<String, Object>) parsed;
                if (parsedMap.containsKey('errors')) {
                    List<Object> errs = (List<Object>) parsedMap.get('errors');
                    if (errs != null && !errs.isEmpty()) {
                        Map<String, Object> firstErr = (Map<String, Object>) errs[0];
                        throw new ConnectorException('SendGrid Error: ' + firstErr.get('message'));
                    }
                }
            }

            // Healthy: response is an array of bounce records
            if (parsed instanceof List<Object>) {
                List<Object> bounces = (List<Object>) parsed;
                System.debug('SendGridConnector: OK — bounce records returned = ' + bounces.size());
                if (bounces.size() > 50) {
                    System.debug(LoggingLevel.WARN,
                        'SendGridConnector: HIGH BOUNCE RATE detected (' + bounces.size() + ' records)');
                }
            }
        } catch (JSONException je) {
            System.debug('SendGridConnector: Non-JSON response — ' + je.getMessage());
        }
    }
}

