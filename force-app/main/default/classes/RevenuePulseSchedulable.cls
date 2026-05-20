/**
 * @description Schedulable wrapper for the Revenue Pulse Engine.
 * Runs RevenuePulseService.executePulseSync() on a configurable cadence
 * to keep Revenue_Risk__c records in sync with live Incident__c data.
 *
 * Scheduling (run once to activate):
 *   RevenuePulseSchedulable.scheduleDefault();
 *
 * Or manually via Setup → Scheduled Jobs → New:
 *   Cron: 0 0 * * * ? (every hour)
 *
 * @group Automation
 */
public with sharing class RevenuePulseSchedulable implements Schedulable {

    // Default cron: every hour at minute 0
    public static final String DEFAULT_CRON = '0 0 * * * ?';
    public static final String JOB_NAME     = 'SentinelFlow - Revenue Pulse Sync';

    /**
     * @description Entry point invoked by the Salesforce scheduler.
     */
    public void execute(SchedulableContext ctx) {
        try {
            RevenuePulseService.executePulseSync();
            AuditTrailService.log(
                null,
                'RevenuePulseSchedulable',
                'execute',
                null,
                'Revenue Pulse Sync completed successfully.'
            );
        } catch (Exception e) {
            // Log and swallow — never let a scheduled job crash silently
            System.debug(LoggingLevel.ERROR,
                'RevenuePulseSchedulable.execute failed: ' + e.getMessage());
            AuditTrailService.log(
                null,
                'RevenuePulseSchedulable',
                'execute_error',
                null,
                e.getMessage()
            );
        }
    }

    /**
     * @description Schedules the Revenue Pulse sync with the default hourly cron.
     * Safe to call multiple times — aborts any existing job with the same name first.
     */
    @AuraEnabled
    public static String scheduleDefault() {
        return scheduleWithCron(JOB_NAME, DEFAULT_CRON);
    }

    /**
     * @description Schedules with a custom cron expression.
     * @param jobName  Unique name for the scheduled job.
     * @param cronExp  Salesforce cron expression string.
     * @return         The CronTrigger Job ID.
     */
    public static String scheduleWithCron(String jobName, String cronExp) {
        // Abort existing job with same name to avoid duplicates
        abortIfExists(jobName);
        
        RevenuePulseSchedulable job = new RevenuePulseSchedulable();
        String jobId = System.schedule(jobName, cronExp, job);
        
        System.debug('RevenuePulseSchedulable: Scheduled with ID ' + jobId + ' | CRON: ' + cronExp);
        return jobId;
    }

    /**
     * @description Aborts any existing scheduled job with the given name.
     */
    public static void abortIfExists(String jobName) {
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
            AND State NOT IN ('COMPLETE', 'DELETED', 'ERROR')
            WITH USER_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            System.abortJob(existing[0].Id);
            System.debug('RevenuePulseSchedulable: Aborted existing job "' + jobName + '"');
        }
    }

    /**
     * @description Returns the current scheduled job status for the dashboard.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getJobStatus() {
        Map<String, Object> result = new Map<String, Object>{
            'isScheduled' => false,
            'nextFireTime' => null,
            'state' => 'NOT_SCHEDULED'
        };
        
        List<CronTrigger> triggers = [
            SELECT Id, State, NextFireTime, PreviousFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            AND State NOT IN ('COMPLETE', 'DELETED', 'ERROR')
            WITH USER_MODE
            LIMIT 1
        ];
        
        if (!triggers.isEmpty()) {
            CronTrigger ct = triggers[0];
            result.put('isScheduled', true);
            result.put('nextFireTime', ct.NextFireTime);
            result.put('previousFireTime', ct.PreviousFireTime);
            result.put('state', ct.State);
            result.put('jobId', ct.Id);
        }
        
        return result;
    }
}

