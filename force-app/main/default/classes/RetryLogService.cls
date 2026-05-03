/**
 * RetryLogService
 * Records every retry/heal attempt into Retry_Log__c for full audit traceability.
 *
 * Called from SelfHealingEngine on every doRetry(), doRestart(), doEscalate(),
 * and token refresh action so admins can reconstruct the complete recovery timeline.
 *
 * @author  Tomcodex
 * @version 1.0
 */
public with sharing class RetryLogService {

    /**
     * Log a single retry/healing attempt.
     *
     * @param incidentId   The Incident__c being healed
     * @param attempt      The attempt number (1-based)
     * @param action       Action taken: Retry, Restart Service, Escalate, Token Refresh
     * @param result       Result: Success, Failed, Pending
     * @param reason       Reason for failure (or success message)
     */
    public static void log(
        Id incidentId,
        Integer attempt,
        String result,
        String reason
    ) {
        if (incidentId == null) {
            return;
        }

        // Resolve tenant from incident
        Id tenantId = null;
        try {
            Incident__c inc = [
                SELECT Tenant__c FROM Incident__c WHERE Id = :incidentId WITH USER_MODE LIMIT 1
            ];
            tenantId = inc.Tenant__c;
        } catch (Exception ex) {
            // Non-fatal — proceed without tenant
        }

        Retry_Log__c log = new Retry_Log__c(
            Incident__c      = incidentId,
            Retry_Attempt__c = attempt != null ? attempt : 1,
            Result__c        = String.isNotBlank(result) ? result : 'Pending',
            Timestamp__c     = System.now(),
            Tenant__c        = tenantId
        );

        try {
            insert log;
        } catch (Exception ex) {
            // Fail silently — never let audit logging crash the healing pipeline
            SystemLogger.logMessage(
                'RetryLogService',
                'logRetry',
                'ERROR',
                'Failed to insert Retry_Log__c: ' + ex.getMessage()
            );
        }
    }

    /**
     * Bulk log multiple attempts (used when bulk healing incidents).
     */
    public static void logRetryBulk(List<Retry_Log__c> entries) {
        if (entries == null || entries.isEmpty()) {
            return;
        }
        try {
            insert entries;
        } catch (Exception ex) {
            SystemLogger.logMessage(
                'RetryLogService',
                'logRetryBulk',
                'ERROR',
                'Bulk Retry_Log__c insert failed: ' + ex.getMessage()
            );
        }
    }

    /**
     * Get all retry logs for an incident — used by the Timeline LWC.
     */
    @AuraEnabled(cacheable=true)
    public static List<Retry_Log__c> getRetryLogsForIncident(Id incidentId) {
        if (incidentId == null) {
            return new List<Retry_Log__c>();
        }
        return [
            SELECT Id, Name, Retry_Attempt__c,
                   Result__c, Timestamp__c
            FROM   Retry_Log__c
            WHERE  Incident__c = :incidentId
            ORDER BY Retry_Attempt__c ASC, Timestamp__c ASC
        ];
    }
}
