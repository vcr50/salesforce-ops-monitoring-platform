/**
 * LicenseCacheServiceTest
 * Tests for the Platform Cache license layer.
 *
 * @author  Tomcodex
 * @version 2.7
 */
@IsTest
private class LicenseCacheServiceTest {

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
    static void testResolveWithCache() {
        LicenseService.clearCache();

        Test.startTest();
        LicenseService.LicenseInfo info = LicenseCacheService.resolveWithCache();
        Test.stopTest();

        System.assertNotEquals(null, info, 'Should resolve license info');
        System.assertEquals('Professional', info.plan);
        System.assertEquals(true, info.isActive);
    }

    @IsTest
    static void testInvalidateAndResolve() {
        LicenseService.clearCache();

        // Initial resolve
        LicenseService.LicenseInfo first = LicenseCacheService.resolveWithCache();
        System.assertEquals('Professional', first.plan);

        // Change the subscription
        Subscription__c sub = [SELECT Id FROM Subscription__c LIMIT 1];
        sub.Plan__c = 'Enterprise';
        update sub;

        // Invalidate and re-resolve
        Test.startTest();
        LicenseCacheService.invalidate();
        LicenseService.LicenseInfo refreshed = LicenseCacheService.resolveWithCache();
        Test.stopTest();

        System.assertEquals('Enterprise', refreshed.plan, 'Should reflect updated plan after invalidation');
    }

    @IsTest
    static void testIsPlatformCacheAvailable() {
        Test.startTest();
        // In test context, cache partition likely won't exist
        Boolean available = LicenseCacheService.isPlatformCacheAvailable();
        Test.stopTest();

        // Just verify it doesn't throw
        System.assert(available == true || available == false);
    }
}

