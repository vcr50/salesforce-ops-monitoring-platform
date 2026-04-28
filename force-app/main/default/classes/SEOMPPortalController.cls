public with sharing class SEOMPPortalController {
    public class PortalSummary {
        @AuraEnabled public Integer criticalIncidents;
        @AuraEnabled public Integer openIncidents;
        @AuraEnabled public Integer failedIntegrations;
        @AuraEnabled public Integer warningIntegrations;
    }

    public class PortalIncidentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String severity;
        @AuraEnabled public String status;
    }

    public class PortalIntegrationRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String status;
        @AuraEnabled public String responseTime;
    }

    @AuraEnabled(cacheable=true)
    public static PortalSummary getSummary() {
        PortalSummary summary = new PortalSummary();
        summary.criticalIncidents = [
            SELECT COUNT()
            FROM Incident__c
            WHERE Severity__c = 'Critical'
            AND Status__c NOT IN ('Resolved', 'Closed')
        ];
        summary.openIncidents = [
            SELECT COUNT()
            FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
        ];
        summary.failedIntegrations = [
            SELECT COUNT()
            FROM Integration_Log__c
            WHERE Status__c = 'Failed'
        ];
        summary.warningIntegrations = [
            SELECT COUNT()
            FROM Integration_Log__c
            WHERE Status__c = 'Warning'
        ];
        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static List<PortalIncidentRow> getOpenIncidents() {
        List<PortalIncidentRow> rows = new List<PortalIncidentRow>();
        for (Incident__c incidentRecord : [
            SELECT Id, Name, Severity__c, Status__c
            FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            ORDER BY
                Severity__c DESC,
                CreatedDate DESC
            LIMIT 10
        ]) {
            PortalIncidentRow row = new PortalIncidentRow();
            row.id = incidentRecord.Id;
            row.name = incidentRecord.Name;
            row.severity = incidentRecord.Severity__c;
            row.status = incidentRecord.Status__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<PortalIntegrationRow> getActiveIntegrations() {
        List<PortalIntegrationRow> rows = new List<PortalIntegrationRow>();
        for (Integration_Log__c logRecord : [
            SELECT Id, API_Name__c, Status__c, Response_Time__c
            FROM Integration_Log__c
            WHERE Status__c IN ('Failed', 'Warning')
            ORDER BY
                CreatedDate DESC
            LIMIT 10
        ]) {
            PortalIntegrationRow row = new PortalIntegrationRow();
            row.id = logRecord.Id;
            row.apiName = logRecord.API_Name__c;
            row.status = logRecord.Status__c;
            row.responseTime = logRecord.Response_Time__c == null
                ? ''
                : String.valueOf(logRecord.Response_Time__c) + ' ms';
            rows.add(row);
        }
        return rows;
    }
}
