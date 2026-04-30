/**
 * SystemMonitorController
 * Computes health signals and queries system logs for the observability dashboard.
 *
 * @author Tomcodex
 * @version 1.0
 */
public with sharing class SystemMonitorController {

    public class SystemHealth {
        @AuraEnabled public String  status; // Healthy, Degraded, Critical
        @AuraEnabled public Integer errorCount1H;
        @AuraEnabled public Integer failedJobs;
        @AuraEnabled public Integer activeIncidents;
    }

    @AuraEnabled(cacheable=true)
    public static SystemHealth getSystemHealth() {
        SystemHealth health = new SystemHealth();

        // Error count last 1 hour
        Datetime oneHourAgo = Datetime.now().addHours(-1);
        health.errorCount1H = [
            SELECT COUNT() FROM System_Log__c 
            WHERE CreatedDate >= :oneHourAgo
            WITH USER_MODE
        ];

        // Failed jobs (Permanent errors or max retries)
        health.failedJobs = [
            SELECT COUNT() FROM System_Log__c
            WHERE Error_Type__c = 'Permanent' AND CreatedDate = TODAY
            WITH USER_MODE
        ];

        // Active critical incidents
        health.activeIncidents = [
            SELECT COUNT() FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            AND Severity__c = 'Critical'
            WITH USER_MODE
        ];

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

    @AuraEnabled(cacheable=true)
    public static List<System_Log__c> getRecentLogs() {
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
