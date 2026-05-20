/**
 * LicenseValidatorTest
 * Tests for feature-level authorization enforcement.
 *
 * @author  Tomcodex
 * @version 2.7
 */
@IsTest
private class LicenseValidatorTest {

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
    static void testRequirePlanSuccess() {
        LicenseValidator.enforceInTests = true;
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        // Professional plan should satisfy a Professional requirement
        LicenseValidator.requirePlan('Professional', 'Test Feature');
        // Should also satisfy Starter requirement
        LicenseValidator.requirePlan('Starter', 'Test Feature');
        Test.stopTest();

        // No exception means success
        System.assert(true, 'requirePlan should not throw for valid plans');
    }

    @IsTest
    static void testRequirePlanFailure() {
        LicenseValidator.enforceInTests = true;
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        Boolean caught = false;
        try {
            LicenseValidator.requirePlan('Enterprise', 'Cross-Org Intel');
        } catch (LicenseValidator.LicenseRequiredException e) {
            caught = true;
            System.assert(e.getMessage().contains('Enterprise'), 'Error should mention required plan');
            System.assert(e.getMessage().contains('Cross-Org Intel'), 'Error should mention feature name');
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'Should throw LicenseRequiredException for Enterprise on Pro plan');
    }

    @IsTest
    static void testCanAccessUnregisteredFeature() {
        LicenseValidator.enforceInTests = true;
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        // In test context, unregistered features return true
        Boolean result = LicenseValidator.canAccess('Nonexistent_Feature');
        Test.stopTest();

        System.assertEquals(true, result, 'Unregistered features should be allowed in test context');
    }

    @IsTest
    static void testCanAccessBlankFeature() {
        LicenseValidator.enforceInTests = true;
        Test.startTest();
        Boolean result = LicenseValidator.canAccess('');
        Test.stopTest();

        System.assertEquals(false, result, 'Blank feature name should return false');
    }

    @IsTest
    static void testGetFeatureAccessMap() {
        LicenseValidator.enforceInTests = true;
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        Map<String, Boolean> accessMap = LicenseValidator.getFeatureAccessMap();
        Test.stopTest();

        System.assertNotEquals(null, accessMap, 'Access map should not be null');
    }

    @IsTest
    static void testGetRequiredPlanForKnownFeature() {
        LicenseValidator.enforceInTests = true;
        LicenseValidator.clearCache();

        Test.startTest();
        String plan = LicenseValidator.getRequiredPlan('Unknown_Feature');
        Test.stopTest();

        System.assertEquals('Free', plan, 'Unknown feature should default to Free plan');
    }

    @IsTest
    static void testRequireFeatureThrowsForExpiredOrg() {
        // Expire the subscription
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Status__c = 'Expired';
        sub.Expiry_Date__c = Date.today().addDays(-10);
        update sub;

        LicenseValidator.enforceInTests = true;
        LicenseService.clearCache();
        LicenseValidator.clearCache();

        Test.startTest();
        Boolean caught = false;
        try {
            LicenseValidator.requirePlan('Starter', 'Basic Feature');
        } catch (LicenseValidator.LicenseRequiredException e) {
            caught = true;
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'Should throw when subscription is expired');
    }
}

