/**
 * LicenseControllerTest
 * Tests for the AuraEnabled frontend controller.
 *
 * @author  Tomcodex
 * @version 2.7
 */
@IsTest
private class LicenseControllerTest {

    @TestSetup
    static void setup() {
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
    static void testGetLicenseInfo() {
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseController.getLicenseInfo();
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals('Professional', info.plan);
        System.assertEquals(true, info.isActive);
    }

    @IsTest
    static void testGetFeatureAccess() {
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        Map<String, Boolean> features = LicenseController.getFeatureAccess();
        Test.stopTest();

        System.assertNotEquals(null, features, 'Feature map should not be null');
    }

    @IsTest
    static void testIsFeatureEnabled() {
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        // Unregistered features default to true in test context
        Boolean enabled = LicenseController.isFeatureEnabled('Some_Feature');
        Test.stopTest();

        System.assertEquals(true, enabled);
    }

    @IsTest
    static void testGetRequiredPlanForFeature() {
        LicenseValidator.clearCache();

        Test.startTest();
        String plan = LicenseController.getRequiredPlanForFeature('Unknown');
        Test.stopTest();

        System.assertEquals('Free', plan);
    }

    @IsTest
    static void testRefreshLicense() {
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseController.refreshLicense();
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals('Professional', info.plan);
    }

    @IsTest
    static void testGetSubscriptionPageData() {
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        LicenseController.SubscriptionPageData data = LicenseController.getSubscriptionPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertNotEquals(null, data.license);
        System.assertNotEquals(null, data.features);
        System.assertEquals('Professional', data.license.plan);
        System.assertNotEquals(null, data.currentMonthIncidents);
    }
}

