/**
 * ScheduledMonitoringJob
 * Proactive monitoring sweep — runs every 15 minutes via scheduled Apex.
 *
 * Detects two failure classes:
 *   1. Failed Integration_Log__c records > 30 min old with no active Incident
 *   2. Integration_Log__c records with no activity in > 60 min (stalled/silent)
 *
 * To schedule:
 *   System.schedule('SentinelFlow Monitor', '0 0,15,30,45 * * * ?',
 *                   new ScheduledMonitoringJob());
 *
 * @author   Tomcodex
 * @version  1.0
 */
global with sharing class ScheduledMonitoringJob implements Schedulable {

    // ── Thresholds ──────────────────────────────────────────────────────────
    @TestVisible private static Integer STALE_FAILURE_MINUTES = 30;
    @TestVisible private static Integer SILENT_FAILURE_MINUTES = 60;

    // ── Schedulable entry point ──────────────────────────────────────────────
    global void execute(SchedulableContext sc) {
        sweepStaleFailed();
        sweepSilentStalled();
    }

    // ── Public so it can be invoked manually from dev console ────────────────
    public static void sweepStaleFailed() {
        Datetime threshold = System.now().addMinutes(-STALE_FAILURE_MINUTES);

        // Failed logs older than threshold
        List<Integration_Log__c> staleLogs = [
            SELECT Id, API_Name__c, Error_Message__c, Tenant__c, Response_Time__c
            FROM   Integration_Log__c
            WHERE  Status__c = 'Failed'
            AND    LastModifiedDate < :threshold
            AND    LastModifiedDate <= :threshold
        ];

        if (staleLogs.isEmpty()) {
            return;
        }

        // Only create incidents for logs that don't already have an open incident
        Set<Id> logIds = new Map<Id, Integration_Log__c>(staleLogs).keySet();
        Set<Id> logIdsWithOpenIncident = new Set<Id>();
        for (Incident__c inc : [
            SELECT Integration_Log__c
            FROM   Incident__c
            WHERE  Integration_Log__c IN :logIds
            AND    Status__c NOT IN ('Resolved', 'Closed')
            AND    Status__c NOT IN ('Resolved', 'Closed')
        ]) {
            logIdsWithOpenIncident.add(inc.Integration_Log__c);
        }

        List<Incident__c> incidentsToCreate = new List<Incident__c>();
        for (Integration_Log__c log : staleLogs) {
            if (logIdsWithOpenIncident.contains(log.Id)) {
                continue;
            }
            Incident__c inc = new Incident__c(
                Status__c          = 'New',
                Severity__c        = 'High',
                Description__c     = 'Silent failure detected by scheduled monitor. '
                                   + 'Integration: ' + log.API_Name__c
                                   + (String.isBlank(log.Error_Message__c) ? '' : ' | Error: ' + log.Error_Message__c),
                Integration_Log__c = log.Id,
                Tenant__c          = log.Tenant__c,
                Error_Type__c      = 'Silent Failure',
                Auto_Heal_Status__c = 'Not Attempted'
            );
            incidentsToCreate.add(inc);
        }

        if (!incidentsToCreate.isEmpty()) {
            insert incidentsToCreate;

            // Queue AI analysis for newly created incidents
            List<Id> newIds = new List<Id>();
            for (Incident__c inc : incidentsToCreate) {
                newIds.add(inc.Id);
            }
            System.enqueueJob(new AIAnalysisQueueable(newIds));

            SystemLogger.logMessage(
                'ScheduledMonitoringJob',
                'sweepStaleFailed',
                'INFO',
                'Created ' + incidentsToCreate.size() + ' incidents from stale failed logs.'
            );
        }
    }

    public static void sweepSilentStalled() {
        Datetime threshold = System.now().addMinutes(-SILENT_FAILURE_MINUTES);

        // Integration logs that haven't been updated in > 60 min and are not 'Success'
        List<Integration_Log__c> silentLogs = [
            SELECT Id, API_Name__c, Error_Message__c, Tenant__c, Status__c
            FROM   Integration_Log__c
            WHERE  Status__c NOT IN ('Success', 'Warning')
            AND    LastModifiedDate < :threshold
            AND    LastModifiedDate <= :threshold
        ];

        if (silentLogs.isEmpty()) {
            return;
        }

        // Check for existing open incidents
        Set<Id> logIds = new Map<Id, Integration_Log__c>(silentLogs).keySet();
        Set<Id> logIdsWithOpenIncident = new Set<Id>();
        for (Incident__c inc : [
            SELECT Integration_Log__c
            FROM   Incident__c
            WHERE  Integration_Log__c IN :logIds
            AND    Status__c NOT IN ('Resolved', 'Closed')
            AND    Status__c NOT IN ('Resolved', 'Closed')
        ]) {
            logIdsWithOpenIncident.add(inc.Integration_Log__c);
        }

        List<Incident__c> incidentsToCreate = new List<Incident__c>();
        for (Integration_Log__c log : silentLogs) {
            if (logIdsWithOpenIncident.contains(log.Id)) {
                continue;
            }
            incidentsToCreate.add(new Incident__c(
                Status__c           = 'New',
                Severity__c         = 'Medium',
                Description__c      = 'Stalled integration detected. No activity for '
                                    + SILENT_FAILURE_MINUTES + ' minutes. Integration: '
                                    + log.API_Name__c + ' | Last status: ' + log.Status__c,
                Integration_Log__c  = log.Id,
                Tenant__c           = log.Tenant__c,
                Error_Type__c       = 'Stalled Integration',
                Auto_Heal_Status__c = 'Not Attempted'
            ));
        }

        if (!incidentsToCreate.isEmpty()) {
            insert incidentsToCreate;

            List<Id> newIds = new List<Id>();
            for (Incident__c inc : incidentsToCreate) {
                newIds.add(inc.Id);
            }
            System.enqueueJob(new AIAnalysisQueueable(newIds));

            SystemLogger.logMessage(
                'ScheduledMonitoringJob',
                'sweepSilentStalled',
                'INFO',
                'Created ' + incidentsToCreate.size() + ' incidents from silent/stalled logs.'
            );
        }
    }
}
