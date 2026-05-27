public with sharing class SentinelFlowSlackAlertService {
    public enum AlertType {
        CRITICAL_INCIDENT,
        APPROVAL_REQUIRED,
        ACTION_EXECUTED,
        CASE_CREATED,
        ORG_HEALTH_WATCH,
        DELIVERY_ISSUE
    }

    public class AlertMessage {
        public AlertType alertType;
        public String text;
        public String salesforceUrl;
        public Map<String, Object> payload;
    }

    public static AlertMessage formatAlert(AlertType alertType, Id incidentId) {
        if (alertType == null) {
            throw new SentinelFlowSlackAlertException('Alert type is required.');
        }

        if (incidentId == null) {
            throw new SentinelFlowSlackAlertException('Incident id is required.');
        }

        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Name', 'Severity__c', 'Status__c', 'Description__c',
            'Root_Cause__c', 'Recommended_Action__c', 'Revenue_at_Risk__c',
            'Users_Affected__c', 'Auto_Heal_Status__c', 'CreatedDate'
        });

        Incident__c incident = [
            SELECT Id, Name, Severity__c, Status__c, Description__c,
                Root_Cause__c, Recommended_Action__c, Revenue_at_Risk__c,
                Users_Affected__c, Auto_Heal_Status__c, CreatedDate
            FROM Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        return formatAlert(alertType, incident);
    }

    @TestVisible
    static AlertMessage formatAlert(AlertType alertType, Incident__c incident) {
        if (alertType == null) {
            throw new SentinelFlowSlackAlertException('Alert type is required.');
        }

        if (incident == null || incident.Id == null) {
            throw new SentinelFlowSlackAlertException('Incident is required.');
        }

        AlertMessage message = new AlertMessage();
        message.alertType = alertType;
        message.salesforceUrl = buildRecordUrl(incident.Id);
        message.text = buildText(alertType, incident, message.salesforceUrl);
        message.payload = buildPayload(alertType, incident, message.text);
        return message;
    }

    private static String buildText(AlertType alertType, Incident__c incident, String incidentUrl) {
        String alertTypeName = String.valueOf(alertType);

        if (alertTypeName == 'CRITICAL_INCIDENT') {
            return 'SentinelFlow critical incident\n' +
                baseIncidentLines(incident) +
                '\nReview in Salesforce: ' + incidentUrl;
        }

        if (alertTypeName == 'APPROVAL_REQUIRED') {
            return 'SentinelFlow clearance required\n' +
                'Incident: ' + safe(incident.Name) + '\n' +
                'Severity: ' + safe(incident.Severity__c) + '\n' +
                'Recommended action: ' + safe(incident.Recommended_Action__c) + '\n' +
                'Root cause: ' + safe(incident.Root_Cause__c) + '\n\n' +
                'Review in Salesforce: ' + incidentUrl;
        }

        if (alertTypeName == 'ACTION_EXECUTED') {
            return 'SentinelFlow governed action updated\n' +
                'Incident: ' + safe(incident.Name) + '\n' +
                'Auto-heal status: ' + safe(incident.Auto_Heal_Status__c) + '\n' +
                'Incident status: ' + safe(incident.Status__c) + '\n\n' +
                'View execution evidence: ' + incidentUrl;
        }

        if (alertTypeName == 'CASE_CREATED') {
            return 'SentinelFlow case follow-up required\n' +
                'Incident: ' + safe(incident.Name) + '\n' +
                'Case: No case record linked in this SentinelFlow package line\n' +
                'Recommended action: ' + safe(incident.Recommended_Action__c) + '\n\n' +
                'Open Incident: ' + incidentUrl;
        }

        if (alertTypeName == 'ORG_HEALTH_WATCH') {
            return 'SentinelFlow org health watch\n' +
                'Status: ' + safe(incident.Status__c) + '\n' +
                'Severity: ' + safe(incident.Severity__c) + '\n' +
                'Reason: Review current SentinelFlow Command Center posture.\n\n' +
                'Open Command Center: ' + getSalesforceBaseUrl();
        }

        return 'SentinelFlow alert delivery issue\n' +
            'Context: Slack alert delivery requires review\n' +
            'Status: Safe failure context only\n\n' +
            'Review system health: ' + getSalesforceBaseUrl();
    }

    private static String baseIncidentLines(Incident__c incident) {
        return 'Incident: ' + safe(incident.Name) + '\n' +
            'Severity: ' + safe(incident.Severity__c) + '\n' +
            'Status: ' + safe(incident.Status__c) + '\n' +
            'Users affected: ' + numberLabel(incident.Users_Affected__c) + '\n' +
            'Revenue at risk: ' + currencyLabel(incident.Revenue_at_Risk__c) + '\n' +
            'Recommended action: ' + safe(incident.Recommended_Action__c) + '\n';
    }

    private static Map<String, Object> buildPayload(
        AlertType alertType,
        Incident__c incident,
        String text
    ) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('text', text);
        payload.put('eventType', String.valueOf(alertType));
        payload.put('incidentName', safe(incident.Name));
        payload.put('severity', safe(incident.Severity__c));
        payload.put('status', safe(incident.Status__c));
        payload.put('rootCause', safe(incident.Root_Cause__c));
        payload.put('recommendedAction', safe(incident.Recommended_Action__c));
        payload.put('revenueAtRisk', incident.Revenue_at_Risk__c);
        payload.put('usersAffected', incident.Users_Affected__c);
        payload.put('autoHealStatus', safe(incident.Auto_Heal_Status__c));
        payload.put('salesforceRecordUrl', buildRecordUrl(incident.Id));
        return payload;
    }

    private static String buildRecordUrl(Id recordId) {
        return getSalesforceBaseUrl() + '/lightning/r/' + String.valueOf(recordId) + '/view';
    }

    private static String getSalesforceBaseUrl() {
        return URL.getOrgDomainUrl().toExternalForm();
    }

    private static String numberLabel(Decimal value) {
        return value == null ? '0' : String.valueOf(value.setScale(0));
    }

    private static String currencyLabel(Decimal value) {
        return value == null ? '$0' : '$' + String.valueOf(value.setScale(0));
    }

    private static String safe(Object value) {
        return value == null || String.isBlank(String.valueOf(value)) ? 'Not reported' : String.valueOf(value);
    }

    public class SentinelFlowSlackAlertException extends Exception {}
}