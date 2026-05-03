/**
 * IncidentRestApi
 * Production REST endpoint for receiving external incident reports
 * from monitoring systems (Datadog, CloudWatch, PagerDuty, custom webhooks).
 *
 * Endpoint: POST /services/apexrest/sentinelflow/incidents
 *
 * Request Body (Bulkified - Array of Objects OR Single Object):
 * [
 *   {
 *     "apiKey":       "tenant-api-key-here",
 *     "system":       "Stripe Payment Gateway",
 *     "error":        "Connection timeout after 30s",
 *     "severity":     "Critical",
 *     "environment":  "Production",
 *     "usersAffected": 1200,
 *     "revenueAtRisk": 84000
 *   }
 * ]
 *
 * @author  Tomcodex
 * @version 2.1 (Hardened Bulkified + Partial Success Processing)
 */
@RestResource(urlMapping='/sentinelflow/incidents/*')
global with sharing class IncidentRestApi {

    // ── Response wrapper ──────────────────────────────────────────────────
    global class ApiResponse {
        public Boolean success;
        public List<String> incidentIds;
        public List<String> errors;
        public String  message;

        public ApiResponse(Boolean success, List<String> incidentIds, List<String> errors, String message) {
            this.success     = success;
            this.incidentIds = incidentIds;
            this.errors      = errors;
            this.message     = message;
        }
    }

    private class IncidentWrapper {
        public String systemName;
        public String errorMsg;
        public String severity;
        public String environment;
        public Integer usersAffected;
        public Decimal revenueAtRisk;
        public Integration_Log__c logRef;
    }

    // ── POST: Create incidents ────────────────────────────────────────────
    @HttpPost
    global static void doPost() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            // ── Global Kill Switch ────────────────────────────────────────
            SentinelFlow_Settings__c settings = SentinelFlow_Settings__c.getOrgDefaults();
            if (settings != null && !settings.Endpoint_Active__c) {
                res.statusCode = 503;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Service Unavailable — endpoint is deactivated by admin.')
                ));
                return;
            }

            // ── FLS / Security Checks ─────────────────────────────────────
            if (!Schema.sObjectType.Integration_Log__c.isCreateable() || !Schema.sObjectType.Incident__c.isCreateable()) {
                res.statusCode = 403;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Forbidden — insufficient permissions to create incidents.')
                ));
                return;
            }

            // Parse the request body (supports single object or array)
            Object parsedBody = JSON.deserializeUntyped(req.requestBody.toString());
            List<Map<String, Object>> requests = new List<Map<String, Object>>();

            if (parsedBody instanceof List<Object>) {
                for (Object obj : (List<Object>)parsedBody) {
                    requests.add((Map<String, Object>)obj);
                }
            } else if (parsedBody instanceof Map<String, Object>) {
                requests.add((Map<String, Object>)parsedBody);
            }

            if (requests.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Bad Request — empty payload.')
                ));
                return;
            }

            // ── Authenticate via API key (using first record) ─────────────
            String apiKey = (String) requests[0].get('apiKey');
            Id tenantId = TenantContext.getTenantIdByApiKey(apiKey);

            if (tenantId == null) {
                tenantId = TenantContext.getCurrentTenantId();
            }

            if (tenantId == null) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Unauthorized — invalid or missing API key.')
                ));
                return;
            }

            // ── API Rate Limiting ─────────────────────────────────────────
            if (RateLimiter.isRateLimited(tenantId, 'INCIDENT_POST')) {
                res.statusCode = 429;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Too Many Requests — API rate limit exceeded.')
                ));
                return;
            }

            // ── Process Bulk Records ──────────────────────────────────────
            List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
            List<IncidentWrapper> wrappers = new List<IncidentWrapper>();

            for (Map<String, Object> body : requests) {
                String systemName  = (String) body.get('system');
                String errorMsg    = (String) body.get('error');
                String severity    = (String) body.get('severity');
                String environment = (String) body.get('environment');

                if (String.isBlank(systemName) || String.isBlank(errorMsg)) continue;

                if (String.isBlank(severity)) severity = 'Medium';
                if (String.isBlank(environment)) environment = 'Production';

                Integer usersAffected = body.containsKey('usersAffected') ? Integer.valueOf(body.get('usersAffected')) : 0;
                Decimal revenueAtRisk = body.containsKey('revenueAtRisk') ? Decimal.valueOf(String.valueOf(body.get('revenueAtRisk'))) : 0;

                Integration_Log__c log = new Integration_Log__c(
                    API_Name__c      = systemName,
                    Status__c        = 'Failed',
                    Error_Message__c = errorMsg,
                    Tenant__c        = tenantId
                );
                logsToInsert.add(log);

                IncidentWrapper wrap = new IncidentWrapper();
                wrap.systemName    = systemName;
                wrap.errorMsg      = errorMsg;
                wrap.severity      = severity;
                wrap.environment   = environment;
                wrap.usersAffected = usersAffected;
                wrap.revenueAtRisk = revenueAtRisk;
                wrap.logRef        = log;
                wrappers.add(wrap);
            }

            if (logsToInsert.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, null, null, 'Bad Request — no valid incidents found in payload.')
                ));
                return;
            }

            // Use partial success to prevent one failure from blocking bulk processing
            Database.SaveResult[] logResults = Database.insert(logsToInsert, false);
            
            List<Incident__c> incsToInsert = new List<Incident__c>();
            List<String> errors = new List<String>();

            for (Integer i = 0; i < logsToInsert.size(); i++) {
                if (logResults[i].isSuccess()) {
                    IncidentWrapper wrap = wrappers[i];
                    Incident__c inc = new Incident__c(
                        Description__c     = wrap.errorMsg,
                        Severity__c        = wrap.severity,
                        // Environment__c     = wrap.environment, // TODO: Resolve Environment Name to ID
                        Status__c          = 'New',
                        Users_Affected__c  = wrap.usersAffected,
                        Revenue_at_Risk__c = wrap.revenueAtRisk,
                        Integration_Log__c = wrap.logRef.Id,
                        Tenant__c          = tenantId
                    );
                    incsToInsert.add(inc);
                } else {
                    for(Database.Error err : logResults[i].getErrors()) {
                        errors.add('Log Insert Error [' + wrappers[i].systemName + ']: ' + err.getMessage());
                    }
                }
            }

            List<Id> newIds = new List<Id>();
            List<String> strIds = new List<String>();

            if (!incsToInsert.isEmpty()) {
                Database.SaveResult[] incResults = Database.insert(incsToInsert, false);

                for (Integer i = 0; i < incsToInsert.size(); i++) {
                    if (incResults[i].isSuccess()) {
                        newIds.add(incsToInsert[i].Id);
                        strIds.add(incsToInsert[i].Id);
                        AuditTrailService.log(incsToInsert[i].Id, 'Incident__c', 'API Incident Created', null, 'Source API | Severity: ' + incsToInsert[i].Severity__c);
                    } else {
                        for(Database.Error err : incResults[i].getErrors()) {
                            errors.add('Incident Insert Error: ' + err.getMessage());
                        }
                    }
                }

                // Queue async AI analysis in bulk for successful inserts
                if (!newIds.isEmpty()) {
                    System.enqueueJob(new AIAnalysisQueueable(newIds));
                }
            }

            // ── Success response ──────────────────────────────────────────
            res.statusCode = errors.isEmpty() ? 201 : 207; // 207 Multi-Status for partial success
            String msg = 'Processed ' + requests.size() + ' requests. Success: ' + strIds.size() + '. Failed: ' + errors.size() + '.';
            
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(errors.isEmpty(), strIds, errors, msg)
            ));

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, null, new List<String>{ex.getMessage()}, 'Internal server error: ' + ex.getMessage())
            ));
        }
    }

    // ── GET: Retrieve incidents for tenant ─────────────────────────────────
    @HttpGet
    global static void doGet() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            // Authenticate
            String apiKey = req.params.get('apiKey');
            Id tenantId = TenantContext.getTenantIdByApiKey(apiKey);
            if (tenantId == null) {
                tenantId = TenantContext.getCurrentTenantId();
            }

            if (tenantId == null) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('{"error":"Unauthorized"}');
                return;
            }

            List<Incident__c> incidents = [
                SELECT Id, Name, Severity__c, Status__c, Description__c, Environment__c,
                       Revenue_at_Risk__c, Users_Affected__c, AI_Confidence__c, AI_Impact_Level__c, CreatedDate
                FROM   Incident__c
                WHERE  Tenant__c = :tenantId
                AND    Status__c NOT IN ('Resolved', 'Closed')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(incidents));

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + ex.getMessage() + '"}');
        }
    }
}
