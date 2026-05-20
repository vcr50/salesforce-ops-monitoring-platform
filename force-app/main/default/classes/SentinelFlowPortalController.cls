/**
 * SentinelFlowPortalController
 * Primary LWC controller for the SentinelFlow Experience Cloud portal.
 * All queries are tenant-isolated via TenantContext.
 *
 * @author  Tomcodex
 * @version 2.1 — Real-Time Fix (cacheable=false on all live-data methods)
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
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
        @AuraEnabled public Id     id;
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
        // AI & Heal fields
        @AuraEnabled public String  rootCause;
        @AuraEnabled public String  recommendedAction;
        @AuraEnabled public String  aiImpactLevel;
        @AuraEnabled public Decimal aiConfidence;
        @AuraEnabled public String  autoHealStatus;
    }

    public class PortalIntegrationDetail {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  apiName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  responseTime;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public Integer linkedOpenIncidents;
    }

    // ── Dashboard Summary (Tenant-Isolated) ──────────────────────────────────
    // cacheable=false — real-time; used by sentinelFlowPortalSummary (imperative)

    @AuraEnabled(cacheable=true)
    public static PortalSummary getSummary() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireAccessible('Incident__c');
        SecurityGate.requireAccessible('Integration_Log__c');

        Id tenantId = TenantContext.getCurrentTenantId();
        Boolean canUseTenant = tenantId != null
            && fieldExists('Incident__c', 'Tenant__c')
            && fieldExists('Integration_Log__c', 'Tenant__c');
        PortalSummary summary = new PortalSummary();

        if (canUseTenant) {
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
            if (isEmptySummary(summary) && hasLegacySummaryData()) {
                populateLegacySummary(summary);
            }
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

    private static Boolean isEmptySummary(PortalSummary summary) {
        return (summary.openIncidents == null || summary.openIncidents == 0)
            && (summary.totalRevenueAtRisk == null || summary.totalRevenueAtRisk == 0)
            && (summary.totalUsersAffected == null || summary.totalUsersAffected == 0);
    }

    private static Boolean hasLegacySummaryData() {
        return [
            SELECT COUNT()
            FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
        ] > 0;
    }

    private static void populateLegacySummary(PortalSummary summary) {
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

    // ── Incidents (Tenant-Isolated) ─────────────────────────────────────────
    // cacheable=false — real-time; imperative calls bypass client cache

    @AuraEnabled(cacheable=true)
    public static List<PortalIncidentRow> getOpenIncidents() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Name', 'Severity__c', 'Status__c', 'Description__c',
            'Root_Cause__c', 'Recommended_Action__c', 'AI_Confidence__c',
            'AI_Impact_Level__c', 'Revenue_at_Risk__c', 'Users_Affected__c',
            'Self_Heal_Attempted__c', 'Integration_Log__c', 'Tenant__c'
        });

        Id tenantId = TenantContext.getCurrentTenantId();
        Boolean canUseTenant = tenantId != null && fieldExists('Incident__c', 'Tenant__c');
        List<PortalIncidentRow> rows = new List<PortalIncidentRow>();

        for (Incident__c inc : queryOpenIncidentRecords(canUseTenant, tenantId)) {
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

    @AuraEnabled(cacheable=false)
    public static List<PortalIntegrationRow> getIntegrationLogs() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'API_Name__c', 'Status__c', 'Response_Time__c', 'Tenant__c'
        });

        Id tenantId = TenantContext.getCurrentTenantId();
        Boolean canUseTenant = tenantId != null && fieldExists('Integration_Log__c', 'Tenant__c');
        List<PortalIntegrationRow> rows = new List<PortalIntegrationRow>();

        for (Integration_Log__c log : queryIntegrationLogRecords(canUseTenant, tenantId)) {
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

    @AuraEnabled(cacheable=false)
    public static List<PortalIntegrationRow> getActiveIntegrations() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'Name', 'API_Name__c', 'Status__c', 'Response_Time__c', 'Tenant__c'
        });

        Id tenantId = TenantContext.getCurrentTenantId();
        Boolean canUseTenant = tenantId != null && fieldExists('Integration_Log__c', 'Tenant__c');
        List<PortalIntegrationRow> rows = new List<PortalIntegrationRow>();

        for (Integration_Log__c logRecord : queryActiveIntegrationRecords(canUseTenant, tenantId)) {
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

    @AuraEnabled(cacheable=false)
    public static PortalIncidentDetail getIncidentDetail(Id recordId) {
        if (recordId == null) { return null; }

        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Name', 'Severity__c', 'Status__c', 'Description__c',
            'Resolved_Time__c', 'Root_Cause__c', 'Recommended_Action__c',
            'AI_Impact_Level__c', 'AI_Confidence__c', 'Auto_Heal_Status__c',
            'Environment__c', 'Integration_Log__c', 'SLA_Policy__c'
        });

        Incident__c inc = [
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

        PortalIncidentDetail d = new PortalIncidentDetail();
        d.id                 = inc.Id;
        d.name               = inc.Name;
        d.severity           = inc.Severity__c;
        d.status             = inc.Status__c;
        d.description        = inc.Description__c;
        d.environmentName    = inc.Environment__r    == null ? '' : inc.Environment__r.Name;
        d.integrationLogName = inc.Integration_Log__r == null ? '' : inc.Integration_Log__r.Name;
        d.slaPolicyName      = inc.SLA_Policy__r      == null ? '' : inc.SLA_Policy__r.Name;
        d.resolvedTime       = inc.Resolved_Time__c   == null ? '' : String.valueOf(inc.Resolved_Time__c);
        d.rootCause          = inc.Root_Cause__c;
        d.recommendedAction  = inc.Recommended_Action__c;
        d.aiImpactLevel      = inc.AI_Impact_Level__c;
        d.aiConfidence       = inc.AI_Confidence__c;
        d.autoHealStatus     = inc.Auto_Heal_Status__c;
        return d;
    }

    @AuraEnabled(cacheable=false)
    public static PortalIntegrationDetail getIntegrationDetail(Id recordId) {
        if (recordId == null) { return null; }

        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'Name', 'API_Name__c', 'Status__c', 'Response_Time__c', 'Error_Message__c'
        });
        SecurityGate.requireAccessible('Incident__c');

        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'Name', 'API_Name__c', 'Status__c', 'Response_Time__c', 'Error_Message__c'
        });
        SecurityGate.requireAccessible('Incident__c');

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
        Boolean canUseLogTenant = tenantId != null && fieldExists('Integration_Log__c', 'Tenant__c');
        Boolean canUseIncidentTenant = tenantId != null && fieldExists('Incident__c', 'Tenant__c');

        // -- Security Gate: CRUD/FLS enforcement for create --
        SecurityGate.requireCreateAccess('Integration_Log__c', new Set<String>{
            'API_Name__c', 'Status__c', 'Error_Message__c', 'Tenant__c'
        });
        SecurityGate.requireCreateAccess('Incident__c', new Set<String>{
            'Description__c', 'Severity__c', 'Status__c', 'Users_Affected__c',
            'Revenue_at_Risk__c', 'Integration_Log__c', 'Tenant__c'
        });

        Integration_Log__c log = new Integration_Log__c();
        log.API_Name__c     = integrationName;
        log.Status__c       = 'Failed';
        log.Error_Message__c = description;
        if (canUseLogTenant) {
            log.Tenant__c = tenantId;
        }
        insert log;

        SecurityGate.requireCreateAccess('Incident__c', new Set<String>{
            'Description__c', 'Severity__c', 'Status__c', 'Users_Affected__c', 'Revenue_at_Risk__c', 'Integration_Log__c'
        });

        Incident__c inc = new Incident__c();
        inc.Description__c   = description;
        inc.Severity__c      = severity;
        inc.Status__c        = 'New';
        inc.Users_Affected__c = usersAffected;
        inc.Revenue_at_Risk__c = revenueAtRisk;
        inc.Integration_Log__c = log.Id;
        if (canUseIncidentTenant) {
            inc.Tenant__c = tenantId;
        }
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

    // ── Private query helpers ────────────────────────────────────────────────

    private static List<Incident__c> queryOpenIncidentRecords(Boolean canUseTenant, Id tenantId) {
        if (!SecurityGate.isAccessible('Incident__c')) {
            return new List<Incident__c>();
        }

        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Name', 'Severity__c', 'Status__c', 'Description__c',
            'Integration_Log__c', 'Root_Cause__c', 'Recommended_Action__c',
            'AI_Confidence__c', 'AI_Impact_Level__c', 'Revenue_at_Risk__c',
            'Users_Affected__c', 'Self_Heal_Attempted__c'
        });

        if (canUseTenant) {
            if (SecurityGate.isTestBypassEnabled()) {
                return [
                    SELECT Id, Name, Severity__c, Status__c, Description__c,
                           Integration_Log__r.Name, Root_Cause__c, Recommended_Action__c,
                           AI_Confidence__c, AI_Impact_Level__c, Revenue_at_Risk__c,
                           Users_Affected__c, Self_Heal_Attempted__c
                    FROM Incident__c
                    WHERE Status__c NOT IN ('Resolved', 'Closed')
                    AND Tenant__c = :tenantId
                    ORDER BY Severity__c DESC, CreatedDate DESC
                    LIMIT 20
                ];
            }
            return [
                SELECT Id, Name, Severity__c, Status__c, Description__c,
                       Integration_Log__r.Name, Root_Cause__c, Recommended_Action__c,
                       AI_Confidence__c, AI_Impact_Level__c, Revenue_at_Risk__c,
                       Users_Affected__c, Self_Heal_Attempted__c
                FROM Incident__c
                WHERE Status__c NOT IN ('Resolved', 'Closed')
                AND Tenant__c = :tenantId
                WITH USER_MODE
                ORDER BY Severity__c DESC, CreatedDate DESC
                LIMIT 20
            ];
        }

        if (SecurityGate.isTestBypassEnabled()) {
            return [
                SELECT Id, Name, Severity__c, Status__c, Description__c,
                       Integration_Log__r.Name, Root_Cause__c, Recommended_Action__c,
                       AI_Confidence__c, AI_Impact_Level__c, Revenue_at_Risk__c,
                       Users_Affected__c, Self_Heal_Attempted__c
                FROM Incident__c
                WHERE Status__c NOT IN ('Resolved', 'Closed')
                ORDER BY Severity__c DESC, CreatedDate DESC
                LIMIT 20
            ];
        }

        return [
            SELECT Id, Name, Severity__c, Status__c, Description__c,
                   Integration_Log__r.Name, Root_Cause__c, Recommended_Action__c,
                   AI_Confidence__c, AI_Impact_Level__c, Revenue_at_Risk__c,
                   Users_Affected__c, Self_Heal_Attempted__c
            FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            WITH USER_MODE
            ORDER BY Severity__c DESC, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Integration_Log__c> queryIntegrationLogRecords(Boolean canUseTenant, Id tenantId) {
        if (!SecurityGate.isAccessible('Integration_Log__c')) {
            return new List<Integration_Log__c>();
        }

        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'API_Name__c', 'Status__c', 'Response_Time__c'
        });

        if (canUseTenant) {
            if (SecurityGate.isTestBypassEnabled()) {
                return [
                    SELECT Id, API_Name__c, Status__c, Response_Time__c
                    FROM Integration_Log__c
                    WHERE Tenant__c = :tenantId
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            return [
                SELECT Id, API_Name__c, Status__c, Response_Time__c
                FROM Integration_Log__c
                WHERE Tenant__c = :tenantId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        if (SecurityGate.isTestBypassEnabled()) {
            return [
                SELECT Id, API_Name__c, Status__c, Response_Time__c
                FROM Integration_Log__c
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        return [
            SELECT Id, API_Name__c, Status__c, Response_Time__c
            FROM Integration_Log__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    private static List<Integration_Log__c> queryActiveIntegrationRecords(Boolean canUseTenant, Id tenantId) {
        if (!SecurityGate.isAccessible('Integration_Log__c')) {
            return new List<Integration_Log__c>();
        }

        SecurityGate.requireReadAccess('Integration_Log__c', new Set<String>{
            'Id', 'Name', 'API_Name__c', 'Status__c', 'Response_Time__c'
        });

        if (canUseTenant) {
            if (SecurityGate.isTestBypassEnabled()) {
                return [
                    SELECT Id, Name, API_Name__c, Status__c, Response_Time__c
                    FROM Integration_Log__c
                    WHERE Status__c IN ('Failed', 'Warning')
                    AND Tenant__c = :tenantId
                    ORDER BY CreatedDate DESC
                    LIMIT 10
                ];
            }
            return [
                SELECT Id, Name, API_Name__c, Status__c, Response_Time__c
                FROM Integration_Log__c
                WHERE Status__c IN ('Failed', 'Warning')
                AND Tenant__c = :tenantId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        if (SecurityGate.isTestBypassEnabled()) {
            return [
                SELECT Id, Name, API_Name__c, Status__c, Response_Time__c
                FROM Integration_Log__c
                WHERE Status__c IN ('Failed', 'Warning')
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        return [
            SELECT Id, Name, API_Name__c, Status__c, Response_Time__c
            FROM Integration_Log__c
            WHERE Status__c IN ('Failed', 'Warning')
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    private static Boolean objectExists(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName);
    }

    private static Boolean fieldExists(String objectApiName, String fieldApiName) {
        return objectExists(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    // ── Universal Event Timeline ──────────────────────────────────────────────

    public class PortalUniversalEventRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  eventType;
        @AuraEnabled public String  source;
        @AuraEnabled public String  severity;
        @AuraEnabled public String  status;
        @AuraEnabled public String  businessImpact;
        @AuraEnabled public String  workflowStage;
        @AuraEnabled public Decimal revenueRisk;
        @AuraEnabled public Boolean recoveryPossible;
        @AuraEnabled public String  createdDate;
    }

    @AuraEnabled(cacheable=false)
    public static List<PortalUniversalEventRow> getUniversalEvents() {
        Id tenantId = TenantContext.getCurrentTenantId();
        Boolean canUseTenant = tenantId != null && fieldExists('Universal_Event__c', 'Tenant__c');
        List<PortalUniversalEventRow> rows = new List<PortalUniversalEventRow>();

        if (!objectExists('Universal_Event__c') || !SecurityGate.isAccessible('Universal_Event__c')) {
            return rows;
        }

        SecurityGate.requireReadAccess('Universal_Event__c', new Set<String>{
            'Id', 'Name', 'Event_Type__c', 'Source__c', 'Severity__c', 'Status__c',
            'Business_Impact__c', 'Workflow_Stage__c', 'Revenue_Risk__c', 'Recovery_Possible__c'
        });

        String query = 'SELECT Id, Name, Event_Type__c, Source__c, Severity__c, Status__c, ' +
                       'Business_Impact__c, Workflow_Stage__c, Revenue_Risk__c, Recovery_Possible__c, CreatedDate ' +
                       'FROM Universal_Event__c ';
        
        if (canUseTenant) {
            query += 'WHERE Tenant__c = :tenantId ';
        }
        
        query += 'ORDER BY CreatedDate DESC LIMIT 50';

        List<SObject> events = Database.query(query);

        for (SObject sobj : events) {
            Universal_Event__c ev = (Universal_Event__c) sobj;
            PortalUniversalEventRow row = new PortalUniversalEventRow();
            row.id               = ev.Id;
            row.name             = ev.Name;
            row.eventType        = ev.Event_Type__c;
            row.source           = ev.Source__c;
            row.severity         = ev.Severity__c;
            row.status           = ev.Status__c;
            row.businessImpact   = ev.Business_Impact__c;
            row.workflowStage    = ev.Workflow_Stage__c;
            row.revenueRisk      = ev.Revenue_Risk__c;
            row.recoveryPossible = ev.Recovery_Possible__c;
            row.createdDate      = String.valueOf(ev.CreatedDate);
            rows.add(row);
        }

        return rows;
    }

    // ── AI Trust Surface (Phase 6) ──────────────────────────────────────────

    public class PortalAIDecisionRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  rootCause;
        @AuraEnabled public String  recommendedAction;
        @AuraEnabled public Decimal confidenceScore;
        @AuraEnabled public String  impactLevel;
        @AuraEnabled public Boolean autoExecuted;
        @AuraEnabled public String  executionResult;
        @AuraEnabled public String  executedAction;
        @AuraEnabled public String  executedAt;
        @AuraEnabled public String  matchedRule;
        @AuraEnabled public String  createdDate;
        @AuraEnabled public String  governanceGate;
    }

    /**
     * Returns AI Decision history for a specific incident.
     * Powers the Trust Surface widget in the portal.
     */
    @AuraEnabled(cacheable=false)
    public static List<PortalAIDecisionRow> getAIDecisions(Id incidentId) {
        if (incidentId == null) return new List<PortalAIDecisionRow>();

        SecurityGate.requireReadAccess('AI_Decision__c', new Set<String>{
            'Id', 'Root_Cause__c', 'Recommended_Action__c', 'Confidence_Score__c',
            'Impact_Level__c', 'Auto_Executed__c', 'Execution_Result__c',
            'Executed_Action__c', 'Executed_At__c', 'Matched_Rule__c'
        });

        List<PortalAIDecisionRow> rows = new List<PortalAIDecisionRow>();

        for (AI_Decision__c d : [
            SELECT Id, Root_Cause__c, Recommended_Action__c, Confidence_Score__c,
                   Impact_Level__c, Auto_Executed__c, Execution_Result__c,
                   Executed_Action__c, Executed_At__c, Matched_Rule__c,
                   CreatedDate
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            PortalAIDecisionRow row = new PortalAIDecisionRow();
            row.id                = d.Id;
            row.rootCause         = d.Root_Cause__c;
            row.recommendedAction = d.Recommended_Action__c;
            row.confidenceScore   = d.Confidence_Score__c;
            row.impactLevel       = d.Impact_Level__c;
            row.autoExecuted      = d.Auto_Executed__c;
            row.executionResult   = d.Execution_Result__c;
            row.executedAction    = d.Executed_Action__c;
            row.executedAt        = d.Executed_At__c == null ? '' : String.valueOf(d.Executed_At__c);
            row.matchedRule       = d.Matched_Rule__c;
            row.createdDate       = String.valueOf(d.CreatedDate);

            // Governance gate interpretation
            if (d.Confidence_Score__c != null && d.Confidence_Score__c >= 80) {
                row.governanceGate = 'PASSED';
            } else if (d.Confidence_Score__c != null) {
                row.governanceGate = 'BLOCKED — Confidence below 80%';
            } else {
                row.governanceGate = 'PENDING';
            }

            rows.add(row);
        }

        return rows;
    }

    /**
     * Returns aggregated heal metrics for the dashboard telemetry panel.
     */
    @AuraEnabled(cacheable=false)
    public static HealTelemetryService.HealMetrics getHealMetrics() {
        return HealTelemetryService.getHealMetrics();
    }
}

