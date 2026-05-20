/**
 * Schedules the full Guardian monitoring sweep for packaged orgs.
 */
global with sharing class FlowHealthSchedulable implements Schedulable {
    global void execute(SchedulableContext context) {
        runSweep();
    }

    public static void runSweep() {
        FlowHealthMonitor.monitorFailedFlows();
        ApexJobMonitor.monitorFailedJobs();
        ScheduledMonitoringJob.sweepStaleFailed();
        ScheduledMonitoringJob.sweepSilentStalled();
    }

    public static String scheduleEveryFifteenMinutes() {
        List<CronTrigger> existingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'SentinelFlow Guardian Sweep%'
            ORDER BY CronJobDetail.Name ASC
            LIMIT 1
        ];
        if (!existingJobs.isEmpty()) {
            return String.valueOf(existingJobs[0].Id);
        }

        List<String> jobIds = new List<String>();
        jobIds.add(System.schedule('SentinelFlow Guardian Sweep 00', '0 0 * * * ?', new FlowHealthSchedulable()));
        jobIds.add(System.schedule('SentinelFlow Guardian Sweep 15', '0 15 * * * ?', new FlowHealthSchedulable()));
        jobIds.add(System.schedule('SentinelFlow Guardian Sweep 30', '0 30 * * * ?', new FlowHealthSchedulable()));
        jobIds.add(System.schedule('SentinelFlow Guardian Sweep 45', '0 45 * * * ?', new FlowHealthSchedulable()));
        return jobIds[0];
    }
}

