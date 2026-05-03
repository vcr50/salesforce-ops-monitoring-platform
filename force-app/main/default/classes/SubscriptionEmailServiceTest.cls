@IsTest
private class SubscriptionEmailServiceTest {
    @IsTest
    static void extractsWebLeadEmail() {
        System.assertEquals(
            'buyer@example.com',
            SubscriptionEmailService.getEmailFromWebLeadOrgId('web-lead:buyer@example.com')
        );
        System.assertEquals(null, SubscriptionEmailService.getEmailFromWebLeadOrgId('00D000000000001AAA'));
        System.assertEquals(null, SubscriptionEmailService.getEmailFromWebLeadOrgId('web-lead:not-an-email'));
    }

    @IsTest
    static void sendsInstallEmailWhenWebLeadSubscriptionBecomesActive() {
        SubscriptionEmailService.installationEmailSendAttempts = 0;

        Test.startTest();
        SubscriptionService.upsertFromBilling(
            'WL1234567890abcdef',
            SubscriptionService.PLAN_PROFESSIONAL,
            SubscriptionService.STATUS_ACTIVE,
            Date.today().addMonths(1),
            'cus_test',
            'sub_test',
            'checkout.session.completed',
            'buyer@example.com'
        );
        Test.stopTest();

        System.assertEquals(1, SubscriptionEmailService.installationEmailSendAttempts);
    }

    @IsTest
    static void doesNotSendInstallEmailForExistingActiveSubscription() {
        SubscriptionEmailService.installationEmailSendAttempts = 0;

        insert new Subscription__c(
            Org_Id__c = 'WLabcdef1234567890',
            Plan__c = SubscriptionService.PLAN_PROFESSIONAL,
            Status__c = SubscriptionService.STATUS_ACTIVE,
            Expiry_Date__c = Date.today().addMonths(1)
        );

        Test.startTest();
        SubscriptionService.upsertFromBilling(
            'WLabcdef1234567890',
            SubscriptionService.PLAN_PROFESSIONAL,
            SubscriptionService.STATUS_ACTIVE,
            Date.today().addMonths(2),
            'cus_test',
            'sub_test',
            'invoice.paid',
            'active@example.com'
        );
        Test.stopTest();

        System.assertEquals(0, SubscriptionEmailService.installationEmailSendAttempts);
    }
}
