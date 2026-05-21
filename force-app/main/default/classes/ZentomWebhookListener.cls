/**
 * ZentomWebhookListener
 * 
 * Receives asynchronous orchestration results from the Zentom AI Python backend.
 * This REST endpoint is called by the Celery worker after it finishes LLM inference.
 * 
 * Authentication: Validates the HMAC-SHA256 signature in the X-Zentom-Signature header
 * using a shared secret stored in Custom Metadata.
 * 
 * Flow:
 * 1. Zentom Celery worker POSTs the result payload here.
 * 2. This class validates the HMAC signature.
 * 3. Parses the AgentforcePayload from the result.
 * 4. Invokes ZentomExecutionController to execute the action in Salesforce.
 * 5. Sends evaluation feedback back to Zentom for the learning loop.
 */
@RestResource(urlMapping='/zentom/callback')
global with sharing class ZentomWebhookListener {
    
    // Shared secret — must match ZENTOM_WEBHOOK_SECRET in the Python .env
    // In production, store this in Custom Metadata or Protected Custom Settings.
    private static final String SHARED_SECRET = 'zentom-sf-shared-secret-v1';
    
    @HttpPost
    global static void handleCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String body = req.requestBody.toString();
        String receivedSignature = req.headers.get('X-Zentom-Signature');
        String traceId = req.headers.get('X-Zentom-Trace-Id');
        
        // ── STEP 1: Validate HMAC Signature ──
        if (String.isBlank(receivedSignature)) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"error":"Missing X-Zentom-Signature header"}');
            System.debug(LoggingLevel.ERROR, '[ZentomWebhook] Rejected: Missing signature header');
            return;
        }
        
        String expectedSignature = generateHmacSha256(body, SHARED_SECRET);
        if (receivedSignature != expectedSignature) {
            res.statusCode = 403;
            res.responseBody = Blob.valueOf('{"error":"Invalid signature"}');
            System.debug(LoggingLevel.ERROR, '[ZentomWebhook] Rejected: Signature mismatch for trace ' + traceId);
            return;
        }
        
        // ── STEP 2: Parse the Payload ──
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            String status = (String) payload.get('status');
            String incidentId = (String) payload.get('incidentId');
            
            if (status != 'SUCCESS') {
                System.debug(LoggingLevel.WARN, 
                    '[ZentomWebhook] Received FAILED status for incident ' + incidentId + 
                    '. No action will be taken.');
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"received":true,"action":"none"}');
                return;
            }
            
            // ── STEP 3: Extract AgentforcePayload ──
            Map<String, Object> afData = (Map<String, Object>) payload.get('agentforcePayload');
            
            if (afData == null) {
                System.debug(LoggingLevel.ERROR, '[ZentomWebhook] Missing agentforcePayload in webhook body');
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Missing agentforcePayload"}');
                return;
            }
            
            String action = (String) afData.get('action');
            Integer confidence = (Integer) afData.get('confidence');
            Decimal riskScore = (Decimal) afData.get('riskScore');
            String executionMode = (String) afData.get('executionMode');
            Boolean agentforceReady = (Boolean) afData.get('agentforceReady');
            
            // ── STEP 4: Execute if cleared by Policy Engine ──
            if (agentforceReady == true) {
                try {
                    ZentomPolicyEngine.ExecutionMode mode = ZentomPolicyEngine.ExecutionMode.valueOf(executionMode);
                    
                    ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
                    risk.totalScore = riskScore;
                    
                    ZentomExecutionController.executeAction(
                        Id.valueOf(incidentId), action, confidence, risk, mode
                    );
                    
                    // ── STEP 5: Send evaluation feedback ──
                    ZentomAIClient.sendEvaluationFeedback(
                        Id.valueOf(incidentId), true, action, confidence
                    );
                    
                    System.debug('[ZentomWebhook] Executed action "' + action + '" for incident ' + incidentId);
                    
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 
                        '[ZentomWebhook] Execution failed for ' + incidentId + ': ' + e.getMessage());
                    ZentomAIClient.sendEvaluationFeedback(
                        Id.valueOf(incidentId), false, action, confidence
                    );
                }
            } else {
                System.debug('[ZentomWebhook] Policy Engine held execution for ' + incidentId + 
                    '. Mode: ' + executionMode);
            }
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"received":true,"action":"' + (agentforceReady ? action : 'held') + '"}');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[ZentomWebhook] Parse error: ' + e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + e.getMessage() + '"}');
        }
    }
    
    /**
     * Generates an HMAC-SHA256 hex digest for signature validation.
     */
    private static String generateHmacSha256(String data, String key) {
        Blob hmacBlob = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(data),
            Blob.valueOf(key)
        );
        return EncodingUtil.convertToHex(hmacBlob);
    }
}
