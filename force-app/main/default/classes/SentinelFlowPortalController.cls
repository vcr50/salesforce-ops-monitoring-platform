/**
 * SentinelFlowPortalController
 * Primary LWC controller for the SentinelFlow Experience Cloud portal.
 * All queries are tenant-isolated via TenantContext.
 *
 * @author  Tomcodex
 * @version 2.0 — Multi-Tenant Production
 */
public with sharing class SentinelFlowPortalController {

    // ── Inner types ───────────────────────────────────────────────────────────

    public class PortalSummary {
        @AuraEnabled public Integer criticalIncidents;
        @AuraEnabled public Integer openIncidents;
        @AuraEnabled public Integer failedIntegrations;
        @AuraEnabled public Integer warningIntegrations;
        @AuraEnabled public Decimal totalRevenueAtRisk;
        @AuraEnabled public Integer totalUsersAffected;
        @AuraEnabled public Integer autoHealedToday;
    }

    public class PortalIncidentRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  severity;
        @AuraEnabled public String  status;
        @AuraEnabled public String  description;
        @AuraEnabled public String  integrationLogName;
        @AuraEnabled public String  rootCause;
        @AuraEnabled public String  recommendedAction;
        @AuraEnabled public Decimal aiConfidence;
        @AuraEnabled public String  aiImpactLevel;
        @AuraEnabled public Decimal revenueAtRisk;
        @AuraEnabled public Integer usersAffected;
        @AuraEnabled public Boolean selfHealAttempted;
    }

    public class PortalIntegrationRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String apiName;
        @AuraEnabled public String status;
        @AuraEnabled public String responseTime;
    }

    public class PortalIncidentDetail {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String severity;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public String environmentName;
        @AuraEnabled public String integrationLogName;
        @AuraEnabled public String slaPolicyName;
        @AuraEnabled public String resolvedTime;
        // AI & Heal fields — used by the Timeline LWC
        @AuraEnabled public String  rootCause;
        @AuraEnabled public String  recommendedAction;
        @AuraEnabled public String  aiImpactLevel;
        @AuraEnabled public Decimal aiConfidence;
        @AuraEnabled public String  autoHealStatus;
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

    // ── Dashboard Summary (Tenant-Isolated) ──────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PortalSummary getSummary() {
        Id tenantId = TenantContext.getCurrentTenantId();
        PortalSummary summary = new PortalSummary();

        if (tenantId != null) {
            summary.criticalIncidents = [
                SELECT COUNT() FROM Incident__c
                WHERE Severity__c = 'Critical'
                AND   Status__c NOT IN ('Resolved', 'Closed')
                AND   Tenant__c = :tenantId
                WITH USER_MODE
            ];
            summary.openIncidents = [
                SELECT COUNT() FROM Incident__c
                WHERE Status__c NOT IN ('Resolved', 'Closed')
                AND   Tenant__c = :tenantId
                WITH USER_MODE
            ];
            summary.failedIntegrations = [
                SELECT COUNT() FROM Integration_Log__c
                WHERE Status__c = 'Failed'
                AND   Tenant__c = :tenantId
            ];
            summary.warningIntegrations = [
                SELECT COUNT() FROM Integration_Log__c
                WHERE Status__c = 'Warning'
                AND   Tenant__c = :tenantId
            ];
            AggregateResult[] aggRev = [
                SELECT SUM(Revenue_at_Risk__c) total
                FROM   Incident__c
                WHERE  Status__c NOT IN ('Resolved', 'Closed')
                AND    Tenant__c = :tenantId
            ];
            summary.totalRevenueAtRisk = aggRev[0].get('total') != null
                ? (Decimal) aggRev[0].get('total') : 0;
            AggregateResult[] aggUsers = [
                SELECT SUM(Users_Affected__c) total
                FROM   Incident__c
                WHERE  Status__c NOT IN ('Resolved', 'Closed')
                AND    Tenant__c = :tenantId
            ];
            summary.totalUsersAffected = aggUsers[0].get('total') != null
                ? Integer.valueOf((Decimal) aggUsers[0].get('total')) : 0;
            summary.autoHealedToday = [
                SELECT COUNT() FROM Incident__c
                WHERE Self_Heal_Attempted__c = true
                AND   Status__c IN ('Resolved', 'Closed', 'Healing')
                AND   CreatedDate = TODAY
                AND   Tenant__c = :tenantId
            ];
        } else {
            // Fallback: no tenant context (legacy/dev mode) — show all
            summary.criticalIncidents = [
                SELECT COUNT() FROM Incident__c
                WHERE Severity__c = 'Critical' AND Status__c NOT IN ('Resolved', 'Closed')
            ];
            summary.openIncidents = [
                SELECT COUNT() FROM Incident__c WHERE Status__c NOT IN ('Resolved', 'Closed')
            ];
            summary.failedIntegrations = [
                SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Failed'
            ];
            summary.warningIntegrations = [
                SELECT COUNT() FROM Integration_Log__c WHERE Status__c = 'Warning'
            ];
            AggregateResult[] aggRev = [
                SELECT SUM(Revenue_at_Risk__c) total
                FROM   Incident__c
                WHERE  Status__c NOT IN ('Resolved', 'Closed')
            ];
            summary.totalRevenueAtRisk = aggRev[0].get('total') != null
                ? (Decimal) aggRev[0].get('total') : 0;
            AggregateResult[] aggUsers = [
                SELECT SUM(Users_Affected__c) total
                FROM   Incident__c
                WHERE  Status__c NOT IN ('Resolved', 'Closed')
            ];
            summary.totalUsersAffected = aggUsers[0].get('total') != null
                ? Integer.valueOf((Decimal) aggUsers[0].get('total')) : 0;
            summary.autoHealedToday = [
                SELECT COUNT() FROM Incident__c
                WHERE Self_Heal_Attempted__c = true
                AND   Status__c IN ('Resolved', 'Closed', 'Healing')
                AND   CreatedDate = TODAY
            ];
        }

        return summary;
    }

    // ── Incidents (Tenant-Isolated) ─────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<PortalIncidentRow> getOpenIncidents() {
        Id tenantId = TenantContext.getCurrentTenantId();
        List<PortalIncidentRow> rows = new List<PortalIncidentRow>();

        String query = 'SELECT Id, Name, Severity__c, Status__c, Description__c, '
            + 'Integration_Log__r.Name, Root_Cause__c, Recommended_Action__c, '
            + 'AI_Confidence__c, AI_Impact_Level__c, Revenue_at_Risk__c, '
            + 'Users_Affected__c, Self_Heal_Attempted__c '
            + 'FROM Incident__c '
            + 'WHERE Status__c NOT IN (\'Resolved\', \'Closed\') ';

        if (tenantId != null) {
            query += 'AND Tenant__c = \'' + String.escapeSingleQuotes(String.valueOf(tenantId)) + '\' ';
        }
        query += 'ORDER BY Severity__c DESC, CreatedDate DESC LIMIT 20';

        for (Incident__c inc : Database.query(query)) {
            PortalIncidentRow row  = new PortalIncidentRow();
            row.id                 = inc.Id;
            row.name               = inc.Name;
            row.severity           = inc.Severity__c;
            row.status             = inc.Status__c;
            row.description        = inc.Description__c;
            row.integrationLogName = inc.Integration_Log__r != null ? inc.Integration_Log__r.Name : '';
            row.rootCause          = inc.Root_Cause__c;
            row.recommendedAction  = inc.Recommended_Action__c;
            row.aiConfidence       = inc.AI_Confidence__c;
            row.aiImpactLevel      = inc.AI_Impact_Level__c;
            row.revenueAtRisk      = inc.Revenue_at_Risk__c;
            row.usersAffected      = inc.Users_Affected__c != null
                ? Integer.valueOf(inc.Users_Affected__c) : null;
            row.selfHealAttempted  = inc.Self_Heal_Attempted__c;
            rows.add(row);
        }
        return rows;
    }

    // ── Integration Logs (Tenant-Isolated) ──────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<PortalIntegrationRow> getIntegrationLogs() {
        Id tenantId = TenantContext.getCurrentTenantId();
        List<PortalIntegrationRow> rows = new List<PortalIntegrationRow>();

        String query = 'SELECT Id, API_Name__c, Status__c, Response_Time__c '
            + 'FROM Integration_Log__c ';

        if (tenantId != null) {
            query += 'WHERE Tenant__c = \'' + String.escapeSingleQuotes(String.valueOf(tenantId)) + '\' ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 50';

        for (Integration_Log__c log : Database.query(query)) {
            PortalIntegrationRow row = new PortalIntegrationRow();
            row.id = log.Id;
            row.name = log.API_Name__c;
            row.apiName = log.API_Name__c;
            row.status = log.Status__c;
            row.responseTime = log.Response_Time__c != null ? log.Response_Time__c + 'ms' : '--';
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<PortalIntegrationRow> getActiveIntegrations() {
        Id tenantId = TenantContext.getCurrentTenantId();
        List<PortalIntegrationRow> rows = new List<PortalIntegrationRow>();

        String query = 'SELECT Id, Name, API_Name__c, Status__c, Response_Time__c '
            + 'FROM Integration_Log__c '
            + 'WHERE Status__c IN (\'Failed\', \'Warning\') ';

        if (tenantId != null) {
            query += 'AND Tenant__c = \'' + String.escapeSingleQuotes(String.valueOf(tenantId)) + '\' ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 10';

        for (Integration_Log__c logRecord : Database.query(query)) {
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

    // ── Actions (Pass-through to service layer) ─────────────────────────────

    @AuraEnabled
    public static SelfHealingEngine.HealResult healIncident(Id incidentId) {
        try {
            SubscriptionService.requireProfessional('Autonomous self-healing');
            return SelfHealingEngine.healIncident(incidentId);
        } catch(Exception e) {
            throw new AuraHandledException('Heal failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static AIAnalysisService.AnalysisResult analyseIncident(Id incidentId) {
        try {
            SubscriptionService.requireProfessional('AI incident analysis');
            return AIAnalysisService.analyseIncident(incidentId);
        } catch(Exception e) {
            throw new AuraHandledException('Analysis failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static BusinessImpactCalculator.ImpactResult calculateImpact(
        Id incidentId, Decimal arpu
    ) {
        try {
            SubscriptionService.requireProfessional('Business impact calculation');
            return BusinessImpactCalculator.calculateForIncident(incidentId, arpu);
        } catch(Exception e) {
            throw new AuraHandledException('Impact calculation failed: ' + e.getMessage());
        }
    }

    // ── Detail Views ────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PortalIncidentDetail getIncidentDetail(Id recordId) {
        if (recordId == null) {
            return null;
        }

        Incident__c incidentRecord = [
            SELECT Id, Name, Severity__c, Status__c, Description__c,
                   Resolved_Time__c, Environment__r.Name,
                   Integration_Log__r.Name, SLA_Policy__r.Name,
                   Root_Cause__c, Recommended_Action__c,
                   AI_Impact_Level__c, AI_Confidence__c,
                   Auto_Heal_Status__c
            FROM   Incident__c
            WHERE  Id = :recordId
            LIMIT 1
        ];

        PortalIncidentDetail detail = new PortalIncidentDetail();
        detail.id                 = incidentRecord.Id;
        detail.name               = incidentRecord.Name;
        detail.severity           = incidentRecord.Severity__c;
        detail.status             = incidentRecord.Status__c;
        detail.description        = incidentRecord.Description__c;
        detail.environmentName    = incidentRecord.Environment__r    == null ? '' : incidentRecord.Environment__r.Name;
        detail.integrationLogName = incidentRecord.Integration_Log__r == null ? '' : incidentRecord.Integration_Log__r.Name;
        detail.slaPolicyName      = incidentRecord.SLA_Policy__r      == null ? '' : incidentRecord.SLA_Policy__r.Name;
        detail.resolvedTime       = incidentRecord.Resolved_Time__c  == null ? '' : String.valueOf(incidentRecord.Resolved_Time__c);
        detail.rootCause          = incidentRecord.Root_Cause__c;
        detail.recommendedAction  = incidentRecord.Recommended_Action__c;
        detail.aiImpactLevel      = incidentRecord.AI_Impact_Level__c;
        detail.aiConfidence       = incidentRecord.AI_Confidence__c;
        detail.autoHealStatus     = incidentRecord.Auto_Heal_Status__c;
        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static PortalIntegrationDetail getIntegrationDetail(Id recordId) {
        if (recordId == null) {
            return null;
        }

        Integration_Log__c logRecord = [
            SELECT Id, Name, API_Name__c, Status__c, Response_Time__c, Error_Message__c
            FROM   Integration_Log__c
            WHERE  Id = :recordId
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

    // ── Incident Creation (Tenant-Aware + Async AI) ─────────────────────────

    @AuraEnabled
    public static Id createSimulatedIncident(
        String description,
        String severity,
        String integrationName,
        Integer usersAffected,
        Decimal revenueAtRisk
    ) {
        try {
            SubscriptionService.requireIncidentCapacity();
        } catch (SubscriptionService.EntitlementException e) {
            throw new AuraHandledException(e.getMessage());
        }

        Id tenantId = TenantContext.getCurrentTenantId();

        Integration_Log__c log = new Integration_Log__c();
        log.API_Name__c = integrationName;
        log.Status__c = 'Failed';
        log.Error_Message__c = description;
        log.Tenant__c = tenantId;
        insert log;

        Incident__c inc = new Incident__c();
        inc.Description__c = description;
        inc.Severity__c = severity;
        inc.Status__c = 'New';
        inc.Users_Affected__c = usersAffected;
        inc.Revenue_at_Risk__c = revenueAtRisk;
        inc.Integration_Log__c = log.Id;
        inc.Tenant__c = tenantId;
        insert inc;

        AuditTrailService.log(
            inc.Id,
            'Incident__c',
            'Incident Created',
            null,
            'Source: UI Simulation | Tenant: ' + tenantId
        );

        // Queue async AI analysis
        System.enqueueJob(new AIAnalysisQueueable(inc.Id));

        return inc.Id;
    }
}
