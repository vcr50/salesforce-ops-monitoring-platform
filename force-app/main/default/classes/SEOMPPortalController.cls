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
        @AuraEnabled public String name;
        @AuraEnabled public String apiName;
        @AuraEnabled public String status;
        @AuraEnabled public String responseTime;
    }

    public class PortalIncidentDetail {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String severity;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public String environmentName;
        @AuraEnabled public String integrationLogName;
        @AuraEnabled public String slaPolicyName;
        @AuraEnabled public String resolvedTime;
    }

    public class PortalIntegrationDetail {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String apiName;
        @AuraEnabled public String status;
        @AuraEnabled public String responseTime;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer linkedOpenIncidents;
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
            row.name = logRecord.Name;
            row.apiName = logRecord.API_Name__c;
            row.status = logRecord.Status__c;
            row.responseTime = logRecord.Response_Time__c == null
                ? ''
                : String.valueOf(logRecord.Response_Time__c) + ' ms';
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static PortalIncidentDetail getIncidentDetail(Id recordId) {
        if (recordId == null) {
            return null;
        }

        Incident__c incidentRecord = [
            SELECT
                Id,
                Name,
                Severity__c,
                Status__c,
                Description__c,
                Resolved_Time__c,
                Environment__r.Name,
                Integration_Log__r.Name,
                SLA_Policy__r.Name
            FROM Incident__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PortalIncidentDetail detail = new PortalIncidentDetail();
        detail.id = incidentRecord.Id;
        detail.name = incidentRecord.Name;
        detail.severity = incidentRecord.Severity__c;
        detail.status = incidentRecord.Status__c;
        detail.description = incidentRecord.Description__c;
        detail.environmentName = incidentRecord.Environment__r == null ? '' : incidentRecord.Environment__r.Name;
        detail.integrationLogName = incidentRecord.Integration_Log__r == null ? '' : incidentRecord.Integration_Log__r.Name;
        detail.slaPolicyName = incidentRecord.SLA_Policy__r == null ? '' : incidentRecord.SLA_Policy__r.Name;
        detail.resolvedTime = incidentRecord.Resolved_Time__c == null
            ? ''
            : String.valueOf(incidentRecord.Resolved_Time__c);
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static PortalIntegrationDetail getIntegrationDetail(Id recordId) {
        if (recordId == null) {
            return null;
        }

        Integration_Log__c logRecord = [
            SELECT
                Id,
                Name,
                API_Name__c,
                Status__c,
                Response_Time__c,
                Error_Message__c
            FROM Integration_Log__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        PortalIntegrationDetail detail = new PortalIntegrationDetail();
        detail.id = logRecord.Id;
        detail.name = logRecord.Name;
        detail.apiName = logRecord.API_Name__c;
        detail.status = logRecord.Status__c;
        detail.responseTime = logRecord.Response_Time__c == null
            ? ''
            : String.valueOf(logRecord.Response_Time__c) + ' ms';
        detail.errorMessage = logRecord.Error_Message__c;
        detail.linkedOpenIncidents = [
            SELECT COUNT()
            FROM Incident__c
            WHERE Integration_Log__c = :logRecord.Id
            AND Status__c NOT IN ('Resolved', 'Closed')
        ];
        return detail;
    }
}
