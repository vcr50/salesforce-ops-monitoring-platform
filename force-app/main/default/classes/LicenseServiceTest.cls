/**
 * LicenseServiceTest
 * Tests for the central license resolution engine.
 * Covers: Free fallback, Subscription-based resolution, plan hierarchy,
 *         expired/trial/active states, and grace period logic.
 *
 * @author  Tomcodex
 * @version 2.7
 */
@IsTest
private class LicenseServiceTest {

    @TestSetup
    static void setup() {
        // Create a subscription for the test org
        Subscription__c sub = new Subscription__c(
            Org_Id__c = UserInfo.getOrganizationId(),
            Plan__c = 'Professional',
            Status__c = 'Active',
            Expiry_Date__c = Date.today().addDays(30),
            Last_Event__c = 'test.setup',
            Last_Sync__c = System.now()
        );
        insert sub;
    }

    @IsTest
    static void testResolveActiveProPlan() {
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals('Professional', info.plan, 'Plan should be Professional');
        System.assertEquals(true, info.isActive, 'License should be active');
        System.assertEquals(false, info.inGracePeriod, 'Should not be in grace period');
        System.assertNotEquals(null, info.orgId, 'Org ID should be populated');
    }

    @IsTest
    static void testHasPlanLevelHierarchy() {
        LicenseService.clearCache();

        Test.startTest();
        Boolean hasStarter = LicenseService.hasPlanLevel('Starter');
        Boolean hasPro = LicenseService.hasPlanLevel('Professional');
        Boolean hasEnterprise = LicenseService.hasPlanLevel('Enterprise');
        Test.stopTest();

        System.assertEquals(true, hasStarter, 'Pro should include Starter');
        System.assertEquals(true, hasPro, 'Pro should include Pro');
        System.assertEquals(false, hasEnterprise, 'Pro should NOT include Enterprise');
    }

    @IsTest
    static void testGetCurrentPlan() {
        LicenseService.clearCache();

        Test.startTest();
        String plan = LicenseService.getCurrentPlan();
        Test.stopTest();

        System.assertEquals('Professional', plan);
    }

    @IsTest
    static void testResolveRefresh() {
        LicenseService.clearCache();

        // First resolve
        LicenseService.LicenseInfo first = LicenseService.resolve();
        System.assertEquals('Professional', first.plan);

        // Update subscription to Enterprise
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Plan__c = 'Enterprise';
        update sub;

        // resolveRefresh should pick up the change
        Test.startTest();
        LicenseService.LicenseInfo refreshed = LicenseService.resolveRefresh();
        Test.stopTest();

        System.assertEquals('Enterprise', refreshed.plan);
    }

    @IsTest
    static void testExpiredSubscriptionDowngradesToFree() {
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Status__c = 'Expired';
        sub.Expiry_Date__c = Date.today().addDays(-10);
        update sub;

        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals('Free', info.plan, 'Expired should downgrade to Free');
        System.assertEquals(false, info.isActive, 'Expired should not be active');
    }

    @IsTest
    static void testGracePeriodActive() {
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Status__c = 'Expired';
        sub.Expiry_Date__c = Date.today().addDays(-3);
        sub.Grace_Period_End__c = Date.today().addDays(4);
        update sub;

        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals(true, info.inGracePeriod, 'Should be in grace period');
        System.assertEquals('Professional', info.plan, 'Plan should be preserved during grace');
    }

    @IsTest
    static void testTrialSubscription() {
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Plan__c = 'Starter';
        sub.Status__c = 'Trial';
        sub.Expiry_Date__c = Date.today().addDays(14);
        update sub;

        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals('Starter', info.plan);
        System.assertEquals('Trial', info.status);
        System.assertEquals(true, info.isActive, 'Trial should be active');
    }

    @IsTest
    static void testNoSubscriptionDefaultsToFree() {
        delete [SELECT Id FROM Subscription__c];
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals('Free', info.plan, 'No subscription should default to Free');
        System.assertEquals(true, info.isActive, 'Free tier should be active');
    }

    @IsTest
    static void testIsLicenseActive() {
        LicenseService.clearCache();

        Test.startTest();
        Boolean active = LicenseService.isLicenseActive();
        Test.stopTest();

        System.assertEquals(true, active);
    }

    @IsTest
    static void testDaysRemainingCalculation() {
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseService.resolve();
        Test.stopTest();

        System.assertEquals(30, info.daysRemaining, 'Days remaining should be 30');
    }
}

