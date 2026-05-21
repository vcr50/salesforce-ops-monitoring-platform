public with sharing class ZentomDashboardController {
    
    private static final String BASE_URL = 'https://zentom-ai-backend-2026.loca.lt';
    private static final String API_KEY = 'ztm-system-key-v1';
    
    // ─── READ-ONLY ENDPOINTS (cacheable for LWC @wire) ──────────────────
    
    @AuraEnabled(cacheable=true)
    public static String getAnalyticsSummary() {
        return callZentomAPI('/api/v1/analytics/summary');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getPredictions() {
        return callZentomAPI('/api/v1/analytics/predictions');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getDeepHealth() {
        return callZentomAPI('/health/deep');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getPendingApprovals() {
        return callZentomAPI('/api/v1/approvals/pending');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getMetrics() {
        return callZentomAPI('/api/v1/metrics');
    }
    
    @AuraEnabled(cacheable=true)
    public static String getAuditLogs() {
        return callZentomAPI('/api/v1/audit/logs?limit=15');
    }
    
    // ─── MUTATING ENDPOINTS (not cacheable) ─────────────────────────────
    
    @AuraEnabled
    public static String approveWorkflow(Integer workflowId, String approvedBy) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('approved_by', approvedBy);
        return callZentomAPIPost('/api/v1/approvals/' + workflowId + '/approve', JSON.serialize(body));
    }
    
    @AuraEnabled
    public static String rejectWorkflow(Integer workflowId, String reason) {
        Map<String, Object> body = new Map<String, Object>();
        body.put('reason', reason);
        return callZentomAPIPost('/api/v1/approvals/' + workflowId + '/reject', JSON.serialize(body));
    }
    
    // ─── HTTP HELPERS ───────────────────────────────────────────────────
    
    private static String callZentomAPI(String path) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + path);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-Key', API_KEY);
        req.setTimeout(15000);
        
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                return res.getBody();
            }
            return '{"error": "HTTP ' + res.getStatusCode() + '"}';
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
    
    private static String callZentomAPIPost(String path, String body) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-API-Key', API_KEY);
        req.setTimeout(15000);
        req.setBody(body);
        
        try {
            HttpResponse res = http.send(req);
            return res.getBody();
        } catch (Exception e) {
            return '{"error": "' + e.getMessage().replaceAll('"', '') + '"}';
        }
    }
}
