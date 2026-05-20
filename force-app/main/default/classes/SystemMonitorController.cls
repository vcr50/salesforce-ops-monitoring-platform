/**
 * SystemMonitorController
 * Computes health signals and queries system logs for the observability dashboard.
 *
 * @author Tomcodex
 * @version 1.0
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class SystemMonitorController {

    public class SystemHealth {
        @AuraEnabled public String  status; // Healthy, Degraded, Critical
        @AuraEnabled public Integer errorCount1H;
        @AuraEnabled public Integer failedJobs;
        @AuraEnabled public Integer activeIncidents;
    }

    public class RuntimeFabricStatus {
        @AuraEnabled public String name;
        @AuraEnabled public String status; // ok, warn, critical
        @AuraEnabled public String label;
    }

    @AuraEnabled(cacheable=true)
    public static SystemHealth getSystemHealth() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireAccessible('System_Log__c');
        SecurityGate.requireAccessible('Incident__c');

        SystemHealth health = new SystemHealth();
        health.errorCount1H = 0;
        health.failedJobs = 0;
        health.activeIncidents = 0;

        if (SecurityGate.isAccessible('System_Log__c')) {
            Datetime oneHourAgo = Datetime.now().addHours(-1);
            health.errorCount1H = [
                SELECT COUNT()
                FROM System_Log__c
                WHERE CreatedDate >= :oneHourAgo
                WITH USER_MODE
            ];

            if (fieldAccessible('System_Log__c', 'Error_Type__c')) {
                health.failedJobs = [
                    SELECT COUNT()
                    FROM System_Log__c
                    WHERE Error_Type__c = 'Permanent'
                    AND CreatedDate = TODAY
                    WITH USER_MODE
                ];
            }
        }

        if (SecurityGate.isAccessible('Incident__c')) {
            health.activeIncidents = [
                SELECT COUNT()
                FROM Incident__c
                WHERE Status__c NOT IN ('Resolved', 'Closed')
                AND Severity__c = 'Critical'
                WITH USER_MODE
            ];
        }

        // Compute Health Status
        Integer degradedThreshold = SystemSettings.getInt('HEALTH_DEGRADED_ERRORS', 10);
        Integer criticalThreshold = SystemSettings.getInt('HEALTH_CRITICAL_ERRORS', 50);

        if (health.errorCount1H >= criticalThreshold || health.activeIncidents >= 5) {
            health.status = 'Critical';
        } else if (health.errorCount1H >= degradedThreshold || health.failedJobs > 0) {
            health.status = 'Degraded';
        } else {
            health.status = 'Healthy';
        }

        return health;
    }

    @AuraEnabled(cacheable=false)
    public static List<RuntimeFabricStatus> getRuntimeFabricStatus() {
        List<RuntimeFabricStatus> rows = new List<RuntimeFabricStatus>();

        Integer failedApexJobsToday = 0;
        try {
            failedApexJobsToday = [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE Status = 'Failed'
                AND CreatedDate = TODAY
            ];
        } catch (Exception ignored) {
            failedApexJobsToday = -1;
        }

        if (failedApexJobsToday > 0) {
            rows.add(statusRow('Apex Jobs', 'critical', failedApexJobsToday + ' failed today'));
        } else if (failedApexJobsToday == 0) {
            rows.add(statusRow('Apex Jobs', 'ok', 'No failed jobs today'));
        } else {
            rows.add(statusRow('Apex Jobs', 'warn', 'Job telemetry unavailable'));
        }

        rows.add(
            objectExists('Integration_Health_Event__e')
                ? statusRow('Platform Events', 'ok', 'Integration stream configured')
                : statusRow('Platform Events', 'critical', 'Integration stream missing')
        );

        Integer recentDecisions = countRecentAIDecisions();
        Integer recentExecutions = countRecentAgentforceExecutions();

        if (recentExecutions > 0) {
            rows.add(statusRow('Agentforce', 'ok', recentExecutions + ' executions in 30d'));
        } else if (recentDecisions > 0) {
            rows.add(statusRow('Agentforce', 'warn', 'No recent executions'));
        } else {
            rows.add(statusRow('Agentforce', 'warn', 'No decision telemetry'));
        }

        if (recentDecisions > 0) {
            rows.add(statusRow('Zentom Gen AI', 'ok', recentDecisions + ' decisions in 30d'));
        } else if (objectExists('AI_Decision__c')) {
            rows.add(statusRow('Zentom Gen AI', 'warn', 'No recent decisions'));
        } else {
            rows.add(statusRow('Zentom Gen AI', 'critical', 'Decision object missing'));
        }

        return rows;
    }

    private static Boolean objectExists(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName);
    }

    private static Boolean fieldExists(String objectApiName, String fieldApiName) {
        return objectExists(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean fieldAccessible(String objectApiName, String fieldApiName) {
        return fieldExists(objectApiName, fieldApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap().get(fieldApiName).getDescribe().isAccessible();
    }

    private static RuntimeFabricStatus statusRow(String name, String status, String label) {
        RuntimeFabricStatus row = new RuntimeFabricStatus();
        row.name = name;
        row.status = status;
        row.label = label;
        return row;
    }

    private static Integer countRecentAIDecisions() {
        if (!SecurityGate.isAccessible('AI_Decision__c')) {
            return 0;
        }

        try {
            return [
                SELECT COUNT()
                FROM AI_Decision__c
                WHERE CreatedDate = LAST_N_DAYS:30
                WITH USER_MODE
            ];
        } catch (Exception ignored) {
            return 0;
        }
    }

    private static Integer countRecentAgentforceExecutions() {
        if (!SecurityGate.isAccessible('AI_Decision__c')
            || !fieldAccessible('AI_Decision__c', 'Auto_Executed__c')) {
            return 0;
        }

        try {
            return [
                SELECT COUNT()
                FROM AI_Decision__c
                WHERE CreatedDate = LAST_N_DAYS:30
                AND Auto_Executed__c = true
                WITH USER_MODE
            ];
        } catch (Exception ignored) {
            return 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<System_Log__c> getRecentLogs() {
        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('System_Log__c', new Set<String>{
            'Id', 'Name', 'Class_Name__c', 'Method_Name__c', 'Error_Type__c',
            'Retry_Count__c', 'CreatedDate'
        });

        return [
            SELECT Id, Name, Class_Name__c, Method_Name__c, Error_Type__c, 
                   Retry_Count__c, CreatedDate
            FROM System_Log__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }
}

