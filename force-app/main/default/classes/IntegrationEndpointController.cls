/**
 * IntegrationEndpointController
 * LWC Apex controller for managing Integration_Endpoint__c records
 * from the Settings page. Supports full CRUD for admin-controlled
 * endpoint configuration.
 *
 * @author  Tomcodex
 * @version 1.0
 */
public with sharing class IntegrationEndpointController {

    public class EndpointRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  endpointUrl;
        @AuraEnabled public String  authType;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String  retryPolicy;
        @AuraEnabled public Integer maxRetries;
        @AuraEnabled public Decimal failureCount;
        @AuraEnabled public String  circuitStatus;
    }

    // ── READ ──────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<EndpointRow> getEndpoints() {
        Id tenantId = TenantContext.getCurrentTenantId();
        List<EndpointRow> rows = new List<EndpointRow>();

        String query = 'SELECT Id, Name, Endpoint_URL__c, Auth_Type__c, Active__c, '
            + 'Retry_Policy__c, Max_Retries__c, Failure_Count__c, Circuit_Status__c '
            + 'FROM Integration_Endpoint__c ';

        if (tenantId != null) {
            query += 'WHERE Tenant__c = \'' + String.escapeSingleQuotes(String.valueOf(tenantId)) + '\' ';
        }
        query += 'WITH USER_MODE ORDER BY Name ASC LIMIT 50';

        for (Integration_Endpoint__c ep : Database.query(query)) {
            EndpointRow row = new EndpointRow();
            row.id            = ep.Id;
            row.name          = ep.Name;
            row.endpointUrl   = ep.Endpoint_URL__c;
            row.authType      = ep.Auth_Type__c;
            row.active        = ep.Active__c;
            row.retryPolicy   = ep.Retry_Policy__c;
            row.maxRetries    = ep.Max_Retries__c != null ? Integer.valueOf(ep.Max_Retries__c) : 3;
            row.failureCount  = ep.Failure_Count__c;
            row.circuitStatus = ep.Circuit_Status__c;
            rows.add(row);
        }
        return rows;
    }

    // ── CREATE ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Id createEndpoint(
        String name,
        String endpointUrl,
        String authType,
        String retryPolicy,
        Integer maxRetries
    ) {
        Id tenantId = TenantContext.getCurrentTenantId();

        Integration_Endpoint__c ep = new Integration_Endpoint__c(
            Name            = name,
            Endpoint_URL__c = endpointUrl,
            Auth_Type__c    = authType,
            Retry_Policy__c = retryPolicy,
            Max_Retries__c  = maxRetries != null ? maxRetries : 3,
            Active__c       = true,
            Circuit_Status__c = 'Closed',
            Failure_Count__c  = 0,
            Tenant__c       = tenantId
        );
        insert ep;

        AuditTrailService.log(ep.Id, 'Integration_Endpoint__c', 'Endpoint Created', null,
            'Name: ' + name + ' | Auth: ' + authType);
        return ep.Id;
    }

    // ── UPDATE ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void updateEndpoint(
        Id      recordId,
        String  name,
        String  endpointUrl,
        String  authType,
        String  retryPolicy,
        Integer maxRetries,
        Boolean active
    ) {
        update new Integration_Endpoint__c(
            Id              = recordId,
            Name            = name,
            Endpoint_URL__c = endpointUrl,
            Auth_Type__c    = authType,
            Retry_Policy__c = retryPolicy,
            Max_Retries__c  = maxRetries,
            Active__c       = active
        );
        AuditTrailService.log(recordId, 'Integration_Endpoint__c', 'Endpoint Updated', null,
            'Updated by: ' + UserInfo.getUserName());
    }

    // ── CIRCUIT BREAKER RESET ─────────────────────────────────────────────────

    @AuraEnabled
    public static void resetCircuitBreaker(Id endpointId) {
        update new Integration_Endpoint__c(
            Id               = endpointId,
            Circuit_Status__c = 'Closed',
            Failure_Count__c  = 0
        );
        AuditTrailService.log(endpointId, 'Integration_Endpoint__c', 'Circuit Breaker Reset', null,
            'Reset by: ' + UserInfo.getUserName());
    }

    // ── DELETE ────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void deleteEndpoint(Id endpointId) {
        delete new Integration_Endpoint__c(Id = endpointId);
    }
}
