/**
 * UniversalEventNormalizer
 * Converts current SentinelFlow source records into Universal_Event__c.
 *
 * This is the Salesforce-native universal event layer from the CTO blueprint:
 * existing objects remain the operational system of record, while this layer
 * gives Zentom one common event language.
 *
 * SECURITY NOTE:
 * FLS/CRUD checks are intentionally omitted here (bypassed via PMD suppression).
 * This class is designed to run exclusively from trigger/system context where
 * events must be reliably generated regardless of the invoking user's permissions,
 * ensuring complete operational event tracking.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class UniversalEventNormalizer {

    private static final Map<String, Decimal> DEFAULT_ARPU = new Map<String, Decimal>{
        'Critical' => 40.00,
        'High' => 30.00,
        'Medium' => 20.00,
        'Low' => 10.00
    };

    public static void normalizeIntegrationLogs(List<Integration_Log__c> logs) {
        if (logs == null || logs.isEmpty() || !objectExists('Universal_Event__c')) {
            return;
        }

        Set<Id> logIds = new Set<Id>();
        for (Integration_Log__c logRecord : logs) {
            if (logRecord.Id != null) {
                logIds.add(logRecord.Id);
            }
        }

        Map<Id, IncidentAggregate> incidentByLogId = aggregateIncidentsByLog(logIds);
        List<Universal_Event__c> events = new List<Universal_Event__c>();

        for (Integration_Log__c logRecord : logs) {
            if (logRecord.Id == null) {
                continue;
            }

            IncidentAggregate aggregate = incidentByLogId.get(logRecord.Id);
            String severity = aggregate != null ? aggregate.highestSeverity : severityFromLogStatus(logRecord.Status__c);
            Decimal revenueRisk = aggregate != null ? aggregate.revenueRisk : 0;
            Decimal usersAffected = aggregate != null ? aggregate.usersAffected : 0;

            Universal_Event__c eventRecord = baseEvent('Integration_Log__c', logRecord.Id);
            eventRecord.Source__c = sourceFromApiName(logRecord.API_Name__c);
            eventRecord.Event_Type__c = logRecord.Status__c == 'Success' ? 'RECOVERY' : 'API_FAILURE';
            eventRecord.Severity__c = severity;
            eventRecord.Workflow_Stage__c = workflowStageFromText(logRecord.API_Name__c + ' ' + logRecord.Error_Message__c);
            eventRecord.Business_Impact__c = buildLogImpact(logRecord, severity, revenueRisk, usersAffected);
            eventRecord.Revenue_Risk__c = revenueRisk;
            eventRecord.Users_Affected__c = usersAffected;
            eventRecord.Recovery_Possible__c = logRecord.Status__c == 'Failed' || logRecord.Status__c == 'Warning';
            eventRecord.Status__c = logRecord.Status__c == 'Success' ? 'Resolved' : 'New';
            eventRecord.Tenant__c = getIdValue(logRecord, 'Tenant__c');
            eventRecord.Integration_Log__c = logRecord.Id;
            eventRecord.Integration_Endpoint__c = getIdValue(logRecord, 'Integration_Endpoint__c');
            events.add(eventRecord);
        }

        BusinessGraphEngine.enrichUniversalEvents(events);
        upsertEvents(events);
    }

    public static void normalizeIncidents(List<Incident__c> incidents) {
        if (incidents == null || incidents.isEmpty() || !objectExists('Universal_Event__c')) {
            return;
        }

        List<Universal_Event__c> events = new List<Universal_Event__c>();

        for (Incident__c incidentRecord : incidents) {
            if (incidentRecord.Id == null) {
                continue;
            }

            Decimal users = incidentRecord.Users_Affected__c == null
                ? estimateUsers(incidentRecord.Severity__c)
                : incidentRecord.Users_Affected__c;
            Decimal revenueRisk = incidentRecord.Revenue_at_Risk__c == null
                ? users * arpuForSeverity(incidentRecord.Severity__c)
                : incidentRecord.Revenue_at_Risk__c;

            Universal_Event__c eventRecord = baseEvent('Incident__c', incidentRecord.Id);
            eventRecord.Source__c = 'Salesforce';
            eventRecord.Event_Type__c = 'INCIDENT';
            eventRecord.Severity__c = blankToDefault(incidentRecord.Severity__c, 'High');
            eventRecord.Workflow_Stage__c = workflowStageFromText(incidentRecord.Description__c);
            eventRecord.Business_Impact__c = buildIncidentImpact(incidentRecord, revenueRisk, users);
            eventRecord.Revenue_Risk__c = revenueRisk;
            eventRecord.Users_Affected__c = users;
            eventRecord.Recovery_Possible__c = incidentRecord.Self_Heal_Attempted__c != true;
            eventRecord.Status__c = universalStatusFromIncident(incidentRecord.Status__c);
            eventRecord.Tenant__c = getIdValue(incidentRecord, 'Tenant__c');
            eventRecord.Incident__c = incidentRecord.Id;
            eventRecord.Integration_Log__c = getIdValue(incidentRecord, 'Integration_Log__c');
            eventRecord.Integration_Endpoint__c = getIdValue(incidentRecord, 'Integration_Endpoint__c');
            events.add(eventRecord);
        }

        BusinessGraphEngine.enrichUniversalEvents(events);
        upsertEvents(events);
    }

    public static void normalizeFlowHealth(List<Flow_Health__c> flowHealthRecords) {
        if (flowHealthRecords == null || flowHealthRecords.isEmpty() || !objectExists('Universal_Event__c')) {
            return;
        }

        List<Universal_Event__c> events = new List<Universal_Event__c>();

        for (Flow_Health__c fh : flowHealthRecords) {
            if (fh.Id == null) {
                continue;
            }

            String severity = fh.Last_Run_Status__c == 'Failed' ? 'High' : 'Low';
            Decimal users = estimateUsers(severity);
            Decimal revenueRisk = users * arpuForSeverity(severity);

            Universal_Event__c eventRecord = baseEvent('Flow_Health__c', fh.Id);
            eventRecord.Source__c = 'Salesforce';
            eventRecord.Event_Type__c = fh.Last_Run_Status__c == 'Failed' ? 'FLOW_FAILURE' : 'RECOVERY';
            eventRecord.Severity__c = severity;
            eventRecord.Workflow_Stage__c = workflowStageFromText(fh.Flow_API_Name__c);
            eventRecord.Business_Impact__c = buildFlowHealthImpact(fh, severity, revenueRisk, users);
            eventRecord.Revenue_Risk__c = revenueRisk;
            eventRecord.Users_Affected__c = users;
            eventRecord.Recovery_Possible__c = fh.Last_Run_Status__c == 'Failed';
            eventRecord.Status__c = fh.Last_Run_Status__c == 'Failed' ? 'New' : 'Resolved';
            events.add(eventRecord);
        }

        BusinessGraphEngine.enrichUniversalEvents(events);
        upsertEvents(events);
    }

    private static Universal_Event__c baseEvent(String sourceObject, Id sourceId) {
        Universal_Event__c eventRecord = new Universal_Event__c();
        eventRecord.Event_Key__c = sourceObject + ':' + String.valueOf(sourceId);
        eventRecord.Source_Object__c = sourceObject;
        eventRecord.Source_Record_Id__c = String.valueOf(sourceId);
        return eventRecord;
    }

    private static Map<Id, IncidentAggregate> aggregateIncidentsByLog(Set<Id> logIds) {
        Map<Id, IncidentAggregate> result = new Map<Id, IncidentAggregate>();
        if (logIds == null || logIds.isEmpty() || !objectExists('Incident__c')) {
            return result;
        }

        for (Incident__c incidentRecord : [
            SELECT Integration_Log__c, Severity__c, Revenue_at_Risk__c, Users_Affected__c
            FROM Incident__c
            WHERE Integration_Log__c IN :logIds
            AND Status__c NOT IN ('Resolved', 'Closed')
        ]) {
            IncidentAggregate aggregate = result.get(incidentRecord.Integration_Log__c);
            if (aggregate == null) {
                aggregate = new IncidentAggregate();
                result.put(incidentRecord.Integration_Log__c, aggregate);
            }
            aggregate.revenueRisk += incidentRecord.Revenue_at_Risk__c == null ? 0 : incidentRecord.Revenue_at_Risk__c;
            aggregate.usersAffected += incidentRecord.Users_Affected__c == null ? 0 : incidentRecord.Users_Affected__c;
            aggregate.highestSeverity = higherSeverity(aggregate.highestSeverity, incidentRecord.Severity__c);
        }
        return result;
    }

    private static void upsertEvents(List<Universal_Event__c> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        try {
            upsert events Universal_Event__c.Event_Key__c;
        } catch (Exception ex) {
            SystemLogger.logMessage(
                'UniversalEventNormalizer',
                'upsertEvents',
                'ERROR',
                'Failed to upsert universal events: ' + ex.getMessage()
            );
        }
    }

    private static String buildLogImpact(
        Integration_Log__c logRecord,
        String severity,
        Decimal revenueRisk,
        Decimal usersAffected
    ) {
        String apiName = String.isBlank(logRecord.API_Name__c) ? 'integration' : logRecord.API_Name__c;
        String errorMessage = String.isBlank(logRecord.Error_Message__c) ? 'No error detail captured' : logRecord.Error_Message__c;
        return apiName + ' reported ' + blankToDefault(logRecord.Status__c, 'Unknown')
            + '. Severity ' + severity
            + ', revenue risk $' + revenueRisk.setScale(0).toPlainString()
            + ', users affected ' + String.valueOf(usersAffected.setScale(0))
            + '. Detail: ' + errorMessage;
    }

    private static String buildIncidentImpact(Incident__c incidentRecord, Decimal revenueRisk, Decimal usersAffected) {
        String description = String.isBlank(incidentRecord.Description__c)
            ? 'Incident requires review'
            : incidentRecord.Description__c;
        return description
            + '. Revenue risk $' + revenueRisk.setScale(0).toPlainString()
            + ', users affected ' + String.valueOf(usersAffected.setScale(0)) + '.';
    }

    private static String buildFlowHealthImpact(Flow_Health__c fh, String severity, Decimal revenueRisk, Decimal usersAffected) {
        String apiName = String.isBlank(fh.Flow_API_Name__c) ? 'Unknown Flow' : fh.Flow_API_Name__c;
        String errorMessage = String.isBlank(fh.Error_Message__c) ? 'No error detail captured' : fh.Error_Message__c;
        return 'Flow ' + apiName + ' reported ' + blankToDefault(fh.Last_Run_Status__c, 'Unknown')
            + '. Severity ' + severity
            + ', revenue risk $' + revenueRisk.setScale(0).toPlainString()
            + ', users affected ' + String.valueOf(usersAffected.setScale(0))
            + '. Detail: ' + errorMessage;
    }

    private static String severityFromLogStatus(String status) {
        if (status == 'Failed') {
            return 'High';
        }
        if (status == 'Warning') {
            return 'Medium';
        }
        return 'Low';
    }

    private static String universalStatusFromIncident(String status) {
        if (status == 'Resolved' || status == 'Closed') {
            return 'Resolved';
        }
        if (status == 'Healing') {
            return 'Healing';
        }
        if (status == 'Analyzing') {
            return 'Analyzed';
        }
        if (status == 'Escalated') {
            return 'Governed';
        }
        return 'New';
    }

    private static String sourceFromApiName(String value) {
        String normalized = String.isBlank(value) ? '' : value.toLowerCase();
        if (normalized.contains('stripe')) {
            return 'Stripe';
        }
        if (normalized.contains('hubspot')) {
            return 'HubSpot';
        }
        if (normalized.contains('shopify')) {
            return 'Shopify';
        }
        return 'Salesforce';
    }

    private static String workflowStageFromText(String value) {
        String normalized = String.isBlank(value) ? '' : value.toLowerCase();
        if (normalized.contains('payment') || normalized.contains('stripe') || normalized.contains('checkout')) {
            return 'Payment';
        }
        if (normalized.contains('lead')) {
            return 'Lead Capture';
        }
        if (normalized.contains('renewal')) {
            return 'Renewal';
        }
        if (normalized.contains('fulfillment') || normalized.contains('order')) {
            return 'Fulfillment';
        }
        return 'Operations';
    }

    private static String higherSeverity(String currentValue, String candidate) {
        return severityRank(candidate) > severityRank(currentValue) ? candidate : blankToDefault(currentValue, candidate);
    }

    private static Integer severityRank(String severity) {
        if (severity == 'Critical') return 4;
        if (severity == 'High') return 3;
        if (severity == 'Medium') return 2;
        if (severity == 'Low') return 1;
        return 0;
    }

    private static Decimal estimateUsers(String severity) {
        if (severity == 'Critical') return 1000;
        if (severity == 'High') return 500;
        if (severity == 'Medium') return 100;
        return 25;
    }

    private static Decimal arpuForSeverity(String severity) {
        return DEFAULT_ARPU.containsKey(severity) ? DEFAULT_ARPU.get(severity) : 20.00;
    }

    private static String blankToDefault(String value, String defaultValue) {
        return String.isBlank(value) ? defaultValue : value;
    }

    private static Id getIdValue(SObject record, String fieldName) {
        try {
            Object value = record.get(fieldName);
            return value == null ? null : (Id) value;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Boolean objectExists(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName);
    }

    private class IncidentAggregate {
        Decimal revenueRisk = 0;
        Decimal usersAffected = 0;
        String highestSeverity = 'Low';
    }
}

