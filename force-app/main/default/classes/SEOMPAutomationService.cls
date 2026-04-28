public with sharing class SEOMPAutomationService {
    private static final Set<String> RESOLVED_STATUSES = new Set<String>{ 'Resolved', 'Closed' };
    private static final String FAILED_LOG_STATUS = 'Failed';
    private static final String RECOVERED_LOG_STATUS = 'Success';

    public static void applyIncidentResolutionState(
        List<Incident__c> newRecords,
        Map<Id, Incident__c> oldMap
    ) {
        for (Incident__c incidentRecord : newRecords) {
            Incident__c oldRecord = oldMap == null ? null : oldMap.get(incidentRecord.Id);

            String newStatus = incidentRecord.Status__c;
            String oldStatus = oldRecord == null ? null : oldRecord.Status__c;

            Boolean isNowResolved = RESOLVED_STATUSES.contains(newStatus);
            Boolean wasResolved = RESOLVED_STATUSES.contains(oldStatus);

            if (isNowResolved && incidentRecord.Resolved_Time__c == null) {
                incidentRecord.Resolved_Time__c = System.now();
            } else if (!isNowResolved && wasResolved) {
                incidentRecord.Resolved_Time__c = null;
            }
        }
    }

    public static void createIncidentsForFailedLogs(
        List<Integration_Log__c> newRecords,
        Map<Id, Integration_Log__c> oldMap
    ) {
        Set<Id> failedLogIds = new Set<Id>();
        Map<Id, Integration_Log__c> failedLogsById = new Map<Id, Integration_Log__c>();

        for (Integration_Log__c logRecord : newRecords) {
            if (logRecord.Id == null || logRecord.Status__c != FAILED_LOG_STATUS) {
                continue;
            }

            Integration_Log__c oldRecord = oldMap == null ? null : oldMap.get(logRecord.Id);
            Boolean becameFailed = oldRecord == null || oldRecord.Status__c != FAILED_LOG_STATUS;

            if (becameFailed) {
                failedLogIds.add(logRecord.Id);
                failedLogsById.put(logRecord.Id, logRecord);
            }
        }

        if (failedLogIds.isEmpty()) {
            return;
        }

        Set<Id> logIdsWithOpenIncidents = new Set<Id>();
        for (Incident__c incidentRecord : [
            SELECT Id, Integration_Log__c, Status__c
            FROM Incident__c
            WHERE Integration_Log__c IN :failedLogIds
            AND Status__c NOT IN ('Resolved', 'Closed')
        ]) {
            if (incidentRecord.Integration_Log__c != null) {
                logIdsWithOpenIncidents.add(incidentRecord.Integration_Log__c);
            }
        }

        Map<String, Id> environmentIdsByName = new Map<String, Id>();
        for (Environment__c environmentRecord : [
            SELECT Id, Name
            FROM Environment__c
            WHERE Name IN ('Developer Org', 'QA Sandbox', 'Production')
        ]) {
            environmentIdsByName.put(environmentRecord.Name, environmentRecord.Id);
        }

        Map<String, Id> slaPolicyIdsBySeverity = new Map<String, Id>();
        for (SLA_Policy__c policyRecord : [
            SELECT Id, Severity__c
            FROM SLA_Policy__c
            WHERE Severity__c IN ('Critical', 'High', 'Medium')
        ]) {
            if (!slaPolicyIdsBySeverity.containsKey(policyRecord.Severity__c)) {
                slaPolicyIdsBySeverity.put(policyRecord.Severity__c, policyRecord.Id);
            }
        }

        Id preferredEnvironmentId = environmentIdsByName.containsKey('Production')
            ? environmentIdsByName.get('Production')
            : (environmentIdsByName.containsKey('Developer Org')
                ? environmentIdsByName.get('Developer Org')
                : null);

        List<Incident__c> incidentsToInsert = new List<Incident__c>();

        for (Id logId : failedLogIds) {
            if (logIdsWithOpenIncidents.contains(logId)) {
                continue;
            }

            Integration_Log__c logRecord = failedLogsById.get(logId);
            String severity = deriveSeverity(logRecord);

            Incident__c incidentRecord = new Incident__c();
            incidentRecord.Severity__c = severity;
            incidentRecord.Status__c = 'New';
            incidentRecord.Description__c =
                'Auto-created from failed integration log: ' +
                String.valueOf(logRecord.API_Name__c) +
                (String.isBlank(logRecord.Error_Message__c)
                    ? ''
                    : ' | Error: ' + logRecord.Error_Message__c);
            incidentRecord.Integration_Log__c = logId;
            incidentRecord.Environment__c = preferredEnvironmentId;
            incidentRecord.SLA_Policy__c = slaPolicyIdsBySeverity.get(severity);
            incidentsToInsert.add(incidentRecord);
        }

        if (!incidentsToInsert.isEmpty()) {
            insert incidentsToInsert;
        }
    }

    public static void closeIncidentsForRecoveredLogs(
        List<Integration_Log__c> newRecords,
        Map<Id, Integration_Log__c> oldMap
    ) {
        Set<Id> recoveredLogIds = new Set<Id>();

        for (Integration_Log__c logRecord : newRecords) {
            if (logRecord.Id == null || logRecord.Status__c != RECOVERED_LOG_STATUS) {
                continue;
            }

            Integration_Log__c oldRecord = oldMap == null ? null : oldMap.get(logRecord.Id);
            Boolean recoveredFromFailure = oldRecord != null && oldRecord.Status__c == FAILED_LOG_STATUS;

            if (recoveredFromFailure) {
                recoveredLogIds.add(logRecord.Id);
            }
        }

        if (recoveredLogIds.isEmpty()) {
            return;
        }

        List<Incident__c> incidentsToClose = new List<Incident__c>();
        for (Incident__c incidentRecord : [
            SELECT Id, Status__c
            FROM Incident__c
            WHERE Integration_Log__c IN :recoveredLogIds
            AND Status__c NOT IN ('Resolved', 'Closed')
        ]) {
            incidentRecord.Status__c = 'Closed';
            incidentsToClose.add(incidentRecord);
        }

        if (!incidentsToClose.isEmpty()) {
            update incidentsToClose;
        }
    }

    private static String deriveSeverity(Integration_Log__c logRecord) {
        if (logRecord.Response_Time__c != null && logRecord.Response_Time__c >= 1500) {
            return 'Critical';
        }

        return 'High';
    }
}
