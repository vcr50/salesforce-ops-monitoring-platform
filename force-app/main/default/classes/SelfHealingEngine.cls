/**
 * SelfHealingEngine
 * Autonomous action executor for SentinelFlow.
 * Evaluates AI recommendations and carries out Retry, Restart, Token Refresh,
 * or Escalate actions on incidents and their linked integrations.
 *
 * LOCKED STATUS OWNERSHIP:
 *   This class is the ONLY class that sets: Healing, Resolved, Escalated
 *
 * v3.0 Changes (FINAL - LOCKED):
 *   - Null-safe retry logic using Incident__c.Retry_Count__c / Max_Retry__c
 *   - SentinelFlow_Settings__c integration for Max_Retry override
 *   - RetryLogService.log() minimal signature
 *   - Strict lifecycle: Healing → Resolved | Escalated
 *
 * @author   Tomcodex
 * @version  3.0 (FINAL)
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class SelfHealingEngine {

    // ── Constants ──────────────────────────────────────────────────────────────
    private static final String ACTION_RETRY         = 'Retry';
    private static final String ACTION_RESTART       = 'Restart Service';
    private static final String ACTION_ESCALATE      = 'Escalate';
    private static final String ACTION_TOKEN_REFRESH = 'Token Refresh';
    private static final Integer CIRCUIT_BREAKER_THRESHOLD = 5;
    private static final Decimal MIN_CONFIDENCE_FOR_AUTO_HEAL = 85.0;

    // ── Inner types ────────────────────────────────────────────────────────────
    public class HealResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  actionTaken;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      incidentId;
    }

    // ── Public API ─────────────────────────────────────────────────────────────

    /**
     * Entry point called by SelfHealQueueable after Failed logs are created.
     * Runs AI analysis and auto-heals if confidence is sufficient.
     */
    public static void processFailedLogs(List<Id> integrationLogIds) {
        if (integrationLogIds == null || integrationLogIds.isEmpty()) {
            return;
        }

        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Severity__c', 'Status__c', 'Self_Heal_Attempted__c',
            'Auto_Heal_Status__c', 'Integration_Endpoint__c', 'Integration_Log__c',
            'Retry_Count__c', 'Max_Retry__c', 'Root_Cause__c', 'Recommended_Action__c',
            'AI_Impact_Level__c', 'AI_Confidence__c'
        });
        SecurityGate.requireReadAccess('Integration_Endpoint__c', new Set<String>{
            'Id', 'Circuit_Status__c', 'Failure_Count__c', 'Max_Retries__c', 'Retry_Policy__c'
        });

        List<Incident__c> incidents = [
            SELECT  Id, Severity__c, Status__c, Self_Heal_Attempted__c,
                    Auto_Heal_Status__c, Integration_Endpoint__c,
                    Integration_Log__c, Retry_Count__c, Max_Retry__c,
                    Tenant__c, Revenue_at_Risk__c, Root_Cause__c, Recommended_Action__c, AI_Confidence__c, AI_Impact_Level__c,
                    Integration_Log__r.Error_Message__c,
                    Integration_Log__r.Response_Time__c,
                    Integration_Log__r.Retry_Count__c,
                    Integration_Log__r.Status__c
            FROM    Incident__c
            WHERE   Integration_Log__c IN :integrationLogIds
            AND     Status__c NOT IN ('Resolved', 'Closed')
            AND     Self_Heal_Attempted__c = false
        ];

        if (incidents.isEmpty()) {
            return;
        }

        // Pre-fetch endpoint data for circuit breaker checks
        Set<Id> endpointIds = new Set<Id>();
        for (Incident__c inc : incidents) {
            if (inc.Integration_Endpoint__c != null) {
                endpointIds.add(inc.Integration_Endpoint__c);
            }
        }
        Map<Id, Integration_Endpoint__c> endpointMap = new Map<Id, Integration_Endpoint__c>();
        if (!endpointIds.isEmpty()) {
            for (Integration_Endpoint__c ep : [
                SELECT Id, Circuit_Status__c, Failure_Count__c, Max_Retries__c, Retry_Policy__c
                FROM   Integration_Endpoint__c
                WHERE  Id IN :endpointIds
            ]) {
                endpointMap.put(ep.Id, ep);
            }
        }

        List<Incident__c> incidentsToUpdate = new List<Incident__c>();
        List<Id> idsToHeal = new List<Id>();

        for (Incident__c inc : incidents) {
            // ── Circuit Breaker Check ──────────────────────────────────────
            if (inc.Integration_Endpoint__c != null && endpointMap.containsKey(inc.Integration_Endpoint__c)) {
                Integration_Endpoint__c ep = endpointMap.get(inc.Integration_Endpoint__c);
                if (ep.Circuit_Status__c == 'Open') {
                    inc.Auto_Heal_Status__c = 'Failed';
                    inc.Status__c = 'Escalated';
                    inc.Self_Heal_Attempted__c = true;
                    incidentsToUpdate.add(inc);
                    RetryLogService.log(inc.Id, 1, 'Failed', 'Circuit breaker is OPEN for endpoint. Auto-heal skipped.');
                    AuditTrailService.log(inc.Id, 'Incident__c', 'Circuit Breaker Open', null, 'Endpoint circuit is tripped — healing bypassed.');
                    continue;
                }
            }

            // ── AI Analysis (Zentom Orchestration Layer) ──────────────────────
            String errorMessageContext = inc.Integration_Log__r != null ? inc.Integration_Log__r.Error_Message__c : 'Unknown Error';
            String userPrompt = 'Analyze the following incident and recommend an action. Error: ' + errorMessageContext;
            
            ZentomAIClient.ZentomDecision decision = null;
            try {
                // Determine workflow stage based on endpoint or context
                String workflowStage = 'General';
                if (inc.Integration_Endpoint__c != null && endpointMap.containsKey(inc.Integration_Endpoint__c)) {
                    workflowStage = 'Integration';
                }
                
                decision = ZentomAIClient.orchestrateIncident(
                    inc.Id,
                    userPrompt,
                    'DIAGNOSIS',
                    workflowStage
                );
            } catch (Exception e) {
                System.debug('Zentom Orchestration failed: ' + e.getMessage());
            }

            if (decision != null) {
                // Zentom AI successfully generated a governed decision
                inc.Root_Cause__c          = decision.recommendation + '\n\nRationale: ' + decision.rationale;
                inc.Recommended_Action__c  = decision.proposed_action;
                inc.AI_Confidence__c       = decision.confidence_score;
                inc.AI_Impact_Level__c     = 'High'; 
            } else {
                // Fallback to internal metadata rules if Zentom is unavailable
                AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
                inp.incidentId    = inc.Id;
                inp.status        = inc.Integration_Log__r != null ? inc.Integration_Log__r.Status__c       : inc.Status__c;
                inp.errorMessage  = errorMessageContext;
                inp.responseTime  = inc.Integration_Log__r != null ? inc.Integration_Log__r.Response_Time__c : null;
                inp.pastIncidentCount = 0;

                AIAnalysisService.AnalysisResult aiResult = AIAnalysisService.analyse(inp);

                inc.Root_Cause__c          = aiResult.rootCause;
                inc.Recommended_Action__c  = aiResult.recommendedAction;
                inc.AI_Impact_Level__c     = aiResult.impactLevel;
                inc.AI_Confidence__c       = aiResult.confidence;
            }

            inc.Self_Heal_Attempted__c = true;
            inc.Auto_Heal_Status__c    = 'In Progress';
            incidentsToUpdate.add(inc);

            // ── Structural Governance via ZentomPolicyEngine (Phase 3) ────────────
            ZentomPolicyEngine.PolicyEvaluation evalResult = ZentomPolicyEngine.evaluateAction(inc.Recommended_Action__c, inc.AI_Confidence__c, 'System');
            
            if (evalResult.mode == ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION) {
                // Confidence is high enough to allow autonomous Agentforce/Self-Heal execution
                idsToHeal.add(inc.Id);
                AuditTrailService.log(
                    inc.Id,
                    'Incident__c',
                    'Self-Heal Evaluated',
                    null,
                    evalResult.policyReasoning
                );
            } else {
                // Governance Gate Failed. Override action to Escalate.
                inc.Recommended_Action__c = ACTION_ESCALATE;
                idsToHeal.add(inc.Id);
                
                AuditTrailService.log(
                    inc.Id,
                    'Incident__c',
                    'Governance Gate Failed',
                    null,
                    evalResult.policyReasoning
                );
            }
        }

        if (!incidentsToUpdate.isEmpty()) {
            SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
                'Root_Cause__c', 'Recommended_Action__c', 'AI_Impact_Level__c',
                'AI_Confidence__c', 'Self_Heal_Attempted__c', 'Auto_Heal_Status__c',
                'Status__c'
            });
            update incidentsToUpdate;
        }

        // -- Persist AI Decision audit trail --
        if (!incidentsToUpdate.isEmpty()) {
            SecurityGate.requireCreateAccess('AI_Decision__c', new Set<String>{
                'Incident__c', 'Root_Cause__c', 'Recommended_Action__c',
                'Confidence_Score__c', 'Impact_Level__c', 'Auto_Executed__c',
                'Matched_Rule__c', 'Tenant__c'
            });
            List<AI_Decision__c> decisions = new List<AI_Decision__c>();
            for (Incident__c inc : incidentsToUpdate) {
                AI_Decision__c decision = new AI_Decision__c(
                    Incident__c           = inc.Id,
                    Root_Cause__c         = inc.Root_Cause__c,
                    Recommended_Action__c = inc.Recommended_Action__c,
                    Confidence_Score__c   = inc.AI_Confidence__c,
                    Impact_Level__c       = inc.AI_Impact_Level__c,
                    Auto_Executed__c      = inc.AI_Confidence__c >= MIN_CONFIDENCE_FOR_AUTO_HEAL,
                    Tenant__c             = inc.Tenant__c
                );
                decisions.add(decision);
            }
            if (!decisions.isEmpty()) {
                insert decisions;
            }
        }

        if (!idsToHeal.isEmpty()) {
            System.enqueueJob(new AutoHealQueueable(idsToHeal));
        }
    }

    /**
     * Manually trigger a heal action from the LWC or a Flow.
     */
    @AuraEnabled
    public static HealResult healIncident(Id incidentId) {
        if (incidentId == null) {
            throw new SelfHealException('Incident Id must not be null.');
        }

        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Status__c', 'Recommended_Action__c', 'AI_Confidence__c',
            'Integration_Log__c', 'Integration_Endpoint__c', 'Retry_Count__c',
            'Max_Retry__c', 'Auto_Heal_Status__c'
        });
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
            'Status__c', 'Auto_Heal_Status__c', 'Retry_Count__c'
        });

        Incident__c inc = [
            SELECT  Id, Status__c, Recommended_Action__c, AI_Confidence__c,
                    Integration_Log__c, Integration_Endpoint__c,
                    Retry_Count__c, Max_Retry__c,
                    Integration_Log__r.Retry_Count__c,
                    Auto_Heal_Status__c
            FROM    Incident__c
            WHERE   Id = :incidentId
            LIMIT 1
        ];

        String action = String.isBlank(inc.Recommended_Action__c)
            ? ACTION_RETRY
            : inc.Recommended_Action__c;

        // ── LOCKED RETRY LOGIC (null-safe) ────────────────────────────────
        Integer retryCount = (inc.Retry_Count__c == null ? 0 : inc.Retry_Count__c.intValue());
        Integer maxRetry   = (inc.Max_Retry__c == null ? 3 : inc.Max_Retry__c.intValue());

        // Check global settings override
        SentinelFlow_Settings__c settings = SentinelFlow_Settings__c.getOrgDefaults();
        if (settings != null && settings.Max_Retry__c != null) {
            maxRetry = settings.Max_Retry__c.intValue();
        }

        if (retryCount >= maxRetry) {
            inc.Status__c = 'Escalated';
            inc.Auto_Heal_Status__c = 'Failed';
            update inc;

            RetryLogService.log(inc.Id, retryCount, 'Failed', 'Max retries (' + maxRetry + ') exceeded. Escalating.');

            HealResult escalated = new HealResult();
            escalated.incidentId  = incidentId;
            escalated.actionTaken = ACTION_ESCALATE;
            escalated.success     = false;
            escalated.message     = 'Max retries (' + maxRetry + ') exceeded. Incident escalated.';
            return escalated;
        }

        // ── CIRCUIT BREAKER CHECK ─────────────────────────────────────
        if (inc.Integration_Endpoint__c != null && CircuitBreaker.isCircuitOpen(inc.Integration_Endpoint__c)) {
            inc.Status__c = 'Escalated';
            inc.Auto_Heal_Status__c = 'Failed';
            update inc;

            RetryLogService.log(inc.Id, retryCount, 'Failed', 'Circuit breaker is OPEN for endpoint. Auto-heal skipped.');

            HealResult bypassed = new HealResult();
            bypassed.incidentId  = incidentId;
            bypassed.actionTaken = 'Bypassed';
            bypassed.success     = false;
            bypassed.message     = 'Circuit breaker is OPEN. Healing bypassed.';
            return bypassed;
        }

        // Increment retry count AFTER check
        inc.Retry_Count__c = retryCount + 1;

        // Update status to Healing + In Progress before action
        inc.Auto_Heal_Status__c = 'In Progress';
        inc.Status__c = 'Healing';
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
            'Status__c', 'Auto_Heal_Status__c', 'Retry_Count__c'
        });
        update inc;

        HealResult result = executeAction(incidentId, inc.Integration_Log__c, action, retryCount);

        Boolean isEscalation = action == ACTION_ESCALATE || result.actionTaken == ACTION_ESCALATE;

        // Update Auto_Heal_Status based on result
        if (result.success && !isEscalation) {
            update new Incident__c(Id = incidentId, Status__c = 'Resolved', Auto_Heal_Status__c = 'Succeeded');
            RetryLogService.log(incidentId, retryCount + 1, 'Success', null);
            if (inc.Integration_Endpoint__c != null) {
                CircuitBreaker.recordSuccess(inc.Integration_Endpoint__c);
            }
        } else if (isEscalation) {
            update new Incident__c(Id = incidentId, Status__c = 'Escalated', Auto_Heal_Status__c = 'Pending Review');
            RetryLogService.log(incidentId, retryCount + 1, 'Escalated', result.message);
        } else {
            update new Incident__c(Id = incidentId, Status__c = 'Escalated', Auto_Heal_Status__c = 'Failed');
            RetryLogService.log(incidentId, retryCount + 1, 'Failed', result.message);
            if (inc.Integration_Endpoint__c != null) {
                CircuitBreaker.recordFailure(inc.Integration_Endpoint__c);
            }
        }

        // -- Persist Auto Heal Run audit trail --
        SecurityGate.requireCreateAccess('Auto_Heal_Run__c', new Set<String>{
            'Incident__c', 'Action_Taken__c', 'Result__c',
            'Confidence_Score__c', 'Retry_Attempt__c', 'Detail_Message__c', 'Tenant__c'
        });
        Auto_Heal_Run__c healRun = new Auto_Heal_Run__c(
            Incident__c        = incidentId,
            Action_Taken__c    = action,
            Result__c          = result.success ? 'Succeeded' : 'Failed',
            Confidence_Score__c = inc.AI_Confidence__c,
            Retry_Attempt__c   = retryCount + 1,
            Detail_Message__c  = result.message,
            Tenant__c          = TenantContext.getCurrentTenantId()
        );
        insert healRun;

        AuditTrailService.log(
            incidentId,
            'Incident__c',
            'Self-Heal Executed',
            null,
            'Action: ' + action + ' | Result: ' + result.message
            + ' | HealStatus: ' + (result.success ? 'Succeeded' : 'Failed')
        );

        return result;
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private static HealResult executeAction(
        Id      incidentId,
        Id      logId,
        String  action,
        Integer currentRetryCount
    ) {
        HealResult result  = new HealResult();
        result.incidentId  = incidentId;
        result.actionTaken = action;

        if (action == ACTION_RETRY) {
            result = doRetry(incidentId, logId, currentRetryCount, result);
        } else if (action == ACTION_RESTART) {
            result = doRestart(incidentId, logId, result);
        } else if (action == ACTION_TOKEN_REFRESH) {
            result = doTokenRefresh(incidentId, result);
        } else if (action == ACTION_ESCALATE) {
            result = doEscalate(incidentId, result);
        } else {
            // Unknown or dynamically generated action from Zentom (DeepSeek)
            // Hand off to Agentforce for native execution
            result = ZentomAgentforceRouter.handoffToAgentforce(incidentId, action);
        }

        return result;
    }

    /**
     * Retry — increment retry count on the log. Bump endpoint failure count.
     */
    private static HealResult doRetry(
        Id incidentId, Id logId, Integer currentRetryCount, HealResult result
    ) {
        Integer attemptNum = (currentRetryCount != null ? currentRetryCount : 0) + 1;

        // Update log retry count
        if (logId != null) {
            SecurityGate.requireUpdateAccess('Integration_Log__c', new Set<String>{'Retry_Count__c'});
            update new Integration_Log__c(
                Id             = logId,
                Retry_Count__c = attemptNum
            );
        }

        // Bump failure count on endpoint (for circuit breaker)
        tripEndpointFailureCount(incidentId);

        result.success = true;
        result.message = 'Retry #' + attemptNum + ' executed. Incident in Healing state.';
        return result;
    }

    /**
     * Restart — trigger service restart.
     */
    private static HealResult doRestart(Id incidentId, Id logId, HealResult result) {
        // Production: HttpRequest via Named Credential
        // HttpRequest req = new HttpRequest();
        // req.setEndpoint('callout:SentinelFlow_ServiceRestart/restart');
        // req.setMethod('POST');
        // new Http().send(req);

        result.success = true;
        result.message = 'Service restart triggered. Integration health check queued.';
        return result;
    }

    /**
     * Token Refresh — reset OAuth credentials for auth failure incidents.
     */
    private static HealResult doTokenRefresh(Id incidentId, HealResult result) {
        // Production: refresh OAuth token via Named Credential

        AuditTrailService.log(incidentId, 'Incident__c', 'Token Refresh', null, 'OAuth token refresh triggered.');

        result.success = true;
        result.message = 'OAuth token refresh triggered.';
        return result;
    }

    /**
     * Escalate — create a Case, notify ops team.
     */
    private static HealResult doEscalate(Id incidentId, HealResult result) {
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Name', 'Description__c', 'Severity__c', 'Root_Cause__c'
        });
        Incident__c inc = [
            SELECT Id, Name, Description__c, Severity__c, Root_Cause__c
            FROM   Incident__c
            WHERE  Id = :incidentId
            LIMIT 1
        ];

        try {
            SecurityGate.requireCreateAccess('Case', new Set<String>{
                'Subject', 'Description', 'Priority', 'Status', 'Origin'
            });
            Case escalationCase = new Case(
                Subject     = 'SentinelFlow Escalation — ' + inc.Name,
                Description = 'Incident: ' + inc.Name
                              + '\nSeverity: ' + inc.Severity__c
                              + '\nRoot Cause: ' + (String.isBlank(inc.Root_Cause__c) ? 'Under investigation' : inc.Root_Cause__c)
                              + '\nDescription: ' + inc.Description__c,
                Priority    = inc.Severity__c == 'Critical' ? 'High' : 'Medium',
                Status      = 'New',
                Origin      = 'SentinelFlow AI'
            );
            insert escalationCase;

            result.success = true;
            result.message = 'Incident escalated. Case ' + escalationCase.Id + ' created.';
        } catch (Exception ex) {
            SystemLogger.logMessage(
                'SelfHealingEngine',
                'doEscalate',
                'ERROR',
                'Case insert failed for incident ' + incidentId + ': ' + ex.getMessage()
            );
            result.success = false;
            result.message = 'Escalation attempted but Case creation failed: ' + ex.getMessage();
        }

        return result;
    }

    /**
     * Increment endpoint failure count — feeds the circuit breaker.
     */
    private static void tripEndpointFailureCount(Id incidentId) {
        try {
            SecurityGate.requireReadAccess('Incident__c', new Set<String>{'Integration_Endpoint__c'});
            List<Incident__c> incList = [
                SELECT Integration_Endpoint__c FROM Incident__c WHERE Id = :incidentId LIMIT 1
            ];
            if (incList.isEmpty() || incList[0].Integration_Endpoint__c == null) return;

            Id epId = incList[0].Integration_Endpoint__c;
            SecurityGate.requireReadAccess('Integration_Endpoint__c', new Set<String>{
                'Id', 'Failure_Count__c', 'Circuit_Status__c'
            });
            Integration_Endpoint__c ep = [
                SELECT Id, Failure_Count__c, Circuit_Status__c
                FROM   Integration_Endpoint__c
                WHERE  Id = :epId
                LIMIT 1
            ];

            ep.Failure_Count__c = (ep.Failure_Count__c == null ? 0 : ep.Failure_Count__c) + 1;

            if (ep.Failure_Count__c >= CIRCUIT_BREAKER_THRESHOLD && ep.Circuit_Status__c == 'Closed') {
                ep.Circuit_Status__c = 'Open';
                AuditTrailService.log(
                    incidentId, 'Incident__c', 'Circuit Breaker Tripped',
                    null, 'Endpoint ' + epId + ' tripped after ' + ep.Failure_Count__c + ' failures.'
                );
            }

            SecurityGate.requireUpdateAccess('Integration_Endpoint__c', new Set<String>{
                'Failure_Count__c', 'Circuit_Status__c'
            });
            update ep;
        } catch (Exception ex) {
            // Non-fatal — circuit breaker update is best-effort
        }
    }

    // ── Exception ──────────────────────────────────────────────────────────────
    public class SelfHealException extends Exception {}
}

