/**
 * Daily scheduled job that expires trials past their expiry date.
 */
global with sharing class SubscriptionTrialExpiryScheduler implements Schedulable {
    global void execute(SchedulableContext context) {
        SubscriptionService.expireTrials();
    }
}
