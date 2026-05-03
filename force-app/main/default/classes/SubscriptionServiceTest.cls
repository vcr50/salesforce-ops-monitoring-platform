@IsTest
private class SubscriptionServiceTest {
    @IsTest
    static void createsTrialForCurrentOrg() {
        Test.startTest();
        SubscriptionService.SubscriptionView view = SubscriptionService.getCurrentSubscription();
        Test.stopTest();

        System.assertEquals(UserInfo.getOrganizationId(), view.orgId);
        System.assertEquals(SubscriptionService.PLAN_STARTER, view.plan);
        System.assertEquals(SubscriptionService.STATUS_TRIAL, view.status);
        System.assertEquals(Date.today().addDays(SubscriptionService.TRIAL_DAYS), view.expiryDate);
        System.assertEquals(true, view.active);
    }

    @IsTest
    static void expiredTrialIsMarkedExpired() {
        insert new Subscription__c(
            Org_Id__c = UserInfo.getOrganizationId(),
            Plan__c = SubscriptionService.PLAN_STARTER,
            Status__c = SubscriptionService.STATUS_TRIAL,
            Expiry_Date__c = Date.today().addDays(-1)
        );

        Test.startTest();
        Subscription__c subscription = SubscriptionService.ensureCurrentOrgSubscription();
        Test.stopTest();

        System.assertEquals(SubscriptionService.STATUS_EXPIRED, subscription.Status__c);
    }

    @IsTest
    static void billingUpsertActivatesProfessionalPlan() {
        String orgId = '00D000000000001AAA';

        Test.startTest();
        Subscription__c subscription = SubscriptionService.upsertFromBilling(
            orgId,
            SubscriptionService.PLAN_PROFESSIONAL,
            SubscriptionService.STATUS_ACTIVE,
            Date.today().addMonths(1),
            'cus_test',
            'sub_test',
            'checkout.session.completed'
        );
        Test.stopTest();

        System.assertEquals(orgId, subscription.Org_Id__c);
        System.assertEquals(SubscriptionService.PLAN_PROFESSIONAL, subscription.Plan__c);
        System.assertEquals(SubscriptionService.STATUS_ACTIVE, subscription.Status__c);
        System.assertEquals('cus_test', subscription.Stripe_Customer_Id__c);
    }

    @IsTest
    static void schedulerExpiresOldTrials() {
        insert new Subscription__c(
            Org_Id__c = '00D000000000002AAA',
            Plan__c = SubscriptionService.PLAN_STARTER,
            Status__c = SubscriptionService.STATUS_TRIAL,
            Expiry_Date__c = Date.today().addDays(-2)
        );

        Test.startTest();
        Integer expiredCount = SubscriptionService.expireTrials();
        Test.stopTest();

        System.assertEquals(1, expiredCount);
        System.assertEquals(
            SubscriptionService.STATUS_EXPIRED,
            [SELECT Status__c FROM Subscription__c WHERE Org_Id__c = '00D000000000002AAA' LIMIT 1].Status__c
        );
    }

    @IsTest
    static void scheduledJobRuns() {
        Test.startTest();
        String jobId = System.schedule(
            'Subscription Trial Expiry Test',
            '0 0 1 * * ?',
            new SubscriptionTrialExpiryScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}
