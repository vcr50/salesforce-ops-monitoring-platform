public with sharing class ZentomAIClient {
    // ─── CONFIGURATION ──────────────────────────────────────────────────
    // The public URL to the Zentom AI Python Backend
    // In production, use a Named Credential instead of a hardcoded URL.
    private static final String API_ENDPOINT = 'https://zentom-ai-backend-2026.loca.lt/api/v1/orchestrate';
    
    // The Salesforce REST endpoint that Zentom will POST the result back to.
    // Format: https://<your-org-domain>/services/apexrest/zentom/callback
    private static final String CALLBACK_URL = ''; // Set when org REST endpoint is deployed
    
    // Circuit breaker: max consecutive failures before disabling callouts
    private static final Integer CIRCUIT_BREAKER_THRESHOLD = 3;
    private static final String CIRCUIT_BREAKER_KEY = 'ZentomCircuitBreaker';

    // ─── DATA CONTRACTS ─────────────────────────────────────────────────
    
    public class ZentomDecision {
        @AuraEnabled public String recommendation {get;set;}
        @AuraEnabled public Integer confidence_score {get;set;}
        @AuraEnabled public String proposed_action {get;set;}
        @AuraEnabled public String rationale {get;set;}
    }

    public class AgentforcePayload {
        public String incidentId;
        public String action;
        public Integer confidence;
        public Decimal riskScore;
        public String executionMode;
        public Boolean agentforceReady;
    }
    
    // ─── LEGACY SYNC ORCHESTRATION ──────────────────────────────────────
    public static ZentomDecision getZentomResponse(String userPrompt, String additionalContext) {
        ZentomDecision d = new ZentomDecision();
        d.recommendation = 'Legacy Analysis';
        d.confidence_score = 50;
        d.proposed_action = 'Escalate';
        d.rationale = 'Legacy method fallback';
        return d;
    }
    
    public static ZentomDecision orchestrateIncident(Id incidentId, String userPrompt, String taskType, String workflowStage) {
        ZentomDecision d = new ZentomDecision();
        d.recommendation = 'Legacy Sync Orchestration';
        d.confidence_score = 50;
        d.proposed_action = 'Escalate';
        d.rationale = 'Replaced by orchestrateIncidentAsync';
        return d;
    }
    
    // ─── MASTER ORCHESTRATION (ASYNC FIRE-AND-FORGET) ───────────────────
    
    /**
     * Refactored orchestration method.
     * Instead of blocking synchronously for 120s waiting for LLM inference,
     * this now fires the incident to Zentom asynchronously and exits immediately.
     * The result will arrive via webhook to ZentomWebhookListener.
     *
     * Circuit Breaker: If the backend has failed CIRCUIT_BREAKER_THRESHOLD times
     * consecutively, we skip the callout entirely and log for manual review.
     */
    public static String orchestrateIncidentAsync(Id incidentId, String userPrompt, String taskType, String workflowStage) {
        
        // ── CIRCUIT BREAKER CHECK ──
        Integer failureCount = getCircuitBreakerCount();
        if (failureCount >= CIRCUIT_BREAKER_THRESHOLD) {
            System.debug(LoggingLevel.ERROR, 
                '[ZentomAI] Circuit breaker OPEN — ' + failureCount + ' consecutive failures. ' +
                'Skipping callout for incident ' + incidentId + '. Manual review required.');
            return null;
        }
        
        // 1. Prepare request payload
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('incidentId', (String)incidentId);
        payload.put('userPrompt', userPrompt);
        payload.put('taskType', taskType);
        payload.put('workflowStage', workflowStage);
        payload.put('mock_arr', 150000.0);
        payload.put('mock_error_signature', 'OAuth token expired during payment sync');
        
        // Include callback URL if configured
        if (String.isNotBlank(CALLBACK_URL)) {
            payload.put('callbackUrl', CALLBACK_URL);
        }
        
        // 2. Make Callout (Async — does NOT block for LLM result)
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000); // 10 second timeout — we only need the 202 ACCEPTED
        req.setBody(JSON.serialize(payload));
        
        try {
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 202) {
                // Success — Zentom accepted the incident for processing
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String taskId = (String) jsonResponse.get('taskId');
                
                System.debug('[ZentomAI] Incident ' + incidentId + ' dispatched successfully. TaskId: ' + taskId);
                resetCircuitBreaker();
                return taskId;
                
            } else if (res.getStatusCode() == 200) {
                // Sync mode response (for dev/testing only)
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('[ZentomAI] Sync response received for ' + incidentId);
                resetCircuitBreaker();
                return 'SYNC_COMPLETE';
                
            } else {
                System.debug(LoggingLevel.ERROR, 
                    '[ZentomAI] Unexpected HTTP ' + res.getStatusCode() + ': ' + res.getBody());
                incrementCircuitBreaker();
                return null;
            }
            
        } catch (System.CalloutException e) {
            System.debug(LoggingLevel.ERROR, 
                '[ZentomAI] Callout failed for ' + incidentId + ': ' + e.getMessage());
            incrementCircuitBreaker();
            return null;
        }
    }
    
    // ─── CIRCUIT BREAKER HELPERS ────────────────────────────────────────
    // Uses Org Cache to track consecutive failure count across transactions.
    
    private static Integer getCircuitBreakerCount() {
        try {
            Object val = Cache.Org.get(CIRCUIT_BREAKER_KEY);
            return val != null ? (Integer) val : 0;
        } catch (Exception e) {
            return 0; // Cache not available — assume healthy
        }
    }
    
    private static void incrementCircuitBreaker() {
        try {
            Integer current = getCircuitBreakerCount();
            Cache.Org.put(CIRCUIT_BREAKER_KEY, current + 1, 3600); // TTL 1 hour
        } catch (Exception e) {
            System.debug('[ZentomAI] Could not update circuit breaker cache: ' + e.getMessage());
        }
    }
    
    private static void resetCircuitBreaker() {
        try {
            Cache.Org.remove(CIRCUIT_BREAKER_KEY);
        } catch (Exception e) {
            System.debug('[ZentomAI] Could not reset circuit breaker cache: ' + e.getMessage());
        }
    }
    
    // ─── EVALUATION FEEDBACK ────────────────────────────────────────────
    
    @future(callout=true)
    public static void sendEvaluationFeedback(Id incidentId, Boolean success, String executedAction, Integer confidenceScore) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_ENDPOINT.replace('/orchestrate', '/evaluate'));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000);
        
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('incidentId', (String)incidentId);
        payload.put('executedAction', executedAction);
        payload.put('confidenceScore', confidenceScore);
        payload.put('success', success);
        req.setBody(JSON.serialize(payload));
        
        try {
            http.send(req);
        } catch (Exception e) {
            System.debug('[ZentomAI] Failed to send evaluation feedback: ' + e.getMessage());
        }
    }
}
