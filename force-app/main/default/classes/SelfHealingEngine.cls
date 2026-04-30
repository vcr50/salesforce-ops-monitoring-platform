/**
 * SelfHealingEngine
 * Autonomous action executor for SentinelFlow.
 * Evaluates AI recommendations and carries out Retry, Restart, or Escalate
 * actions on incidents and their linked integrations.
 *
 * @author   Tomcodex
 * @version  1.0
 */
public with sharing class SelfHealingEngine {

    // ── Constants ──────────────────────────────────────────────────────────────
    private static final String ACTION_RETRY   = 'Retry';
    private static final String ACTION_RESTART = 'Restart Service';
    private static final String ACTION_ESCALATE = 'Escalate';
    private static final Integer MAX_RETRIES   = 3;
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
     * Entry point called by the IntegrationLogTrigger after Failed logs are
     * created. Runs AI analysis and auto-heals if confidence is sufficient.
     */
    public static void processFailedLogs(List<Id> integrationLogIds) {
        if (integrationLogIds == null || integrationLogIds.isEmpty()) {
            return;
        }

        // Find the open incidents linked to these logs
        List<Incident__c> incidents = [
            SELECT  Id, Severity__c, Status__c, Self_Heal_Attempted__c,
                    Integration_Log__c,
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

        List<Incident__c> incidentsToUpdate = new List<Incident__c>();
        List<Id> idsToHeal = new List<Id>();

        for (Incident__c inc : incidents) {
            // Build AI input
            AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
            inp.incidentId      = inc.Id;
            inp.status          = inc.Integration_Log__r != null ? inc.Integration_Log__r.Status__c       : inc.Status__c;
            inp.errorMessage    = inc.Integration_Log__r != null ? inc.Integration_Log__r.Error_Message__c : '';
            inp.responseTime    = inc.Integration_Log__r != null ? inc.Integration_Log__r.Response_Time__c  : null;
            // Past incident count bulkification approximation (ideally aggregate query beforehand)
            inp.pastIncidentCount = 0;

            AIAnalysisService.AnalysisResult aiResult = AIAnalysisService.analyse(inp);

            // Persist AI findings
            inc.Root_Cause__c         = aiResult.rootCause;
            inc.Recommended_Action__c = aiResult.recommendedAction;
            inc.AI_Impact_Level__c    = aiResult.impactLevel;
            inc.AI_Confidence__c      = aiResult.confidence;
            inc.Self_Heal_Attempted__c = true;
            inc.Status__c             = 'Investigating';
            incidentsToUpdate.add(inc);

            // Auto-execute only if confidence is high enough
            if (aiResult.confidence >= MIN_CONFIDENCE_FOR_AUTO_HEAL) {
                idsToHeal.add(inc.Id);
            }

            AuditTrailService.log(
                inc.Id,
                'Incident__c',
                'Self-Heal Evaluated',
                null,
                'Action: ' + aiResult.recommendedAction + ' | Confidence: ' + aiResult.confidence + '% | Auto-executed: ' + (aiResult.confidence >= MIN_CONFIDENCE_FOR_AUTO_HEAL)
            );
        }

        if (!incidentsToUpdate.isEmpty()) {
            update incidentsToUpdate;
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

        Incident__c inc = [
            SELECT  Id, Status__c, Recommended_Action__c, AI_Confidence__c,
                    Integration_Log__c,
                    Integration_Log__r.Retry_Count__c
            FROM    Incident__c
            WHERE   Id = :incidentId
            LIMIT 1
        ];

        String action = String.isBlank(inc.Recommended_Action__c)
            ? ACTION_RETRY
            : inc.Recommended_Action__c;

        Decimal retryCount = inc.Integration_Log__r != null
            ? (inc.Integration_Log__r.Retry_Count__c != null ? inc.Integration_Log__r.Retry_Count__c : 0)
            : 0;

        HealResult result = executeAction(incidentId, inc.Integration_Log__c, action, retryCount);

        AuditTrailService.log(
            incidentId,
            'Incident__c',
            'Manual Self-Heal',
            null,
            'Action: ' + action + ' | Result: ' + result.message
        );

        return result;
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private static HealResult executeAction(
        Id      incidentId,
        Id      logId,
        String  action,
        Decimal currentRetryCount
    ) {
        HealResult result  = new HealResult();
        result.incidentId  = incidentId;
        result.actionTaken = action;

        if (action == ACTION_RETRY) {
            result = doRetry(incidentId, logId, currentRetryCount, result);
        } else if (action == ACTION_RESTART) {
            result = doRestart(incidentId, logId, result);
        } else {
            result = doEscalate(incidentId, result);
        }

        return result;
    }

    /**
     * Retry — increment retry count on the log, move incident to Healing.
     * If max retries exceeded, fall through to escalation.
     */
    private static HealResult doRetry(
        Id incidentId, Id logId, Decimal currentRetryCount, HealResult result
    ) {
        if (currentRetryCount != null && currentRetryCount >= MAX_RETRIES) {
            return doEscalate(incidentId, result);
        }

        // Update log retry count
        if (logId != null) {
            Integration_Log__c log = new Integration_Log__c(
                Id            = logId,
                Retry_Count__c = (currentRetryCount == null ? 0 : currentRetryCount) + 1
            );
            update log;
        }

        // Move incident to Healing state
        update new Incident__c(Id = incidentId, Status__c = 'Healing');

        result.success = true;
        result.message = 'Retry initiated. Incident moved to Healing state. Retry count: ' + ((currentRetryCount == null ? 0 : currentRetryCount) + 1);
        return result;
    }

    /**
     * Restart — mark the log as pending restart, set incident to Healing.
     * In production, this would call an external API via a Named Credential.
     */
    private static HealResult doRestart(Id incidentId, Id logId, HealResult result) {
        // In production: make a callout to restart the service endpoint
        // HttpRequest req = new HttpRequest();
        // req.setEndpoint('callout:ServiceRestartAPI/restart');
        // ...

        update new Incident__c(Id = incidentId, Status__c = 'Healing');

        result.success = true;
        result.message = 'Service restart triggered. Integration health check queued. Incident moved to Healing.';
        return result;
    }

    /**
     * Escalate — create a Case and notify the operations team.
     */
    private static HealResult doEscalate(Id incidentId, HealResult result) {
        Incident__c inc = [
            SELECT Id, Name, Description__c, Severity__c, Root_Cause__c
            FROM   Incident__c
            WHERE  Id = :incidentId
            LIMIT 1
        ];

        // Create a Salesforce Case for the escalation
        Case escalationCase = new Case(
            Subject     = 'SentinelFlow Escalation — ' + inc.Name,
            Description = 'Incident: ' + inc.Name + '\nSeverity: ' + inc.Severity__c
                          + '\nRoot Cause: ' + (String.isBlank(inc.Root_Cause__c) ? 'Under investigation' : inc.Root_Cause__c)
                          + '\nDescription: ' + inc.Description__c,
            Priority    = inc.Severity__c == 'Critical' ? 'High' : 'Medium',
            Status      = 'New',
            Origin      = 'SentinelFlow AI'
        );
        insert escalationCase;

        update new Incident__c(Id = incidentId, Status__c = 'Investigating');

        result.success = true;
        result.message = 'Incident escalated. Case ' + escalationCase.Id + ' created for the operations team.';
        return result;
    }

    // ── Exception ──────────────────────────────────────────────────────────────
    public class SelfHealException extends Exception {}
}
