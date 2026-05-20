/**
 * Initializes org-level subscription access when the managed package is installed.
 */
global with sharing class SentinelFlowPostInstallHandler implements InstallHandler {
    global void onInstall(InstallContext context) {
        SubscriptionService.ensureCurrentOrgSubscription();
        scheduleTrialExpiryJob();
        scheduleGuardianSweep();
    }

    private static void scheduleTrialExpiryJob() {
        String jobName = 'SentinelFlow Subscription Trial Expiry';
        List<CronTrigger> existingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];

        if (existingJobs.isEmpty()) {
            System.schedule(
                jobName,
                '0 0 2 * * ?',
                new SubscriptionTrialExpiryScheduler()
            );
        }
    }

    private static void scheduleGuardianSweep() {
        FlowHealthSchedulable.scheduleEveryFifteenMinutes();
    }
}

