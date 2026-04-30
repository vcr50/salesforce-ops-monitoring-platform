/**
 * TenantContextTest
 * Tests tenant resolution logic.
 *
 * @author  Tomcodex
 * @version 1.0
 */
@IsTest
private class TenantContextTest {

    @TestSetup
    static void setupData() {
        Tenant__c tenant = new Tenant__c(
            Name = 'Test Corp',
            Status__c = 'Active',
            API_Key__c = 'test-key-abc-999'
        );
        insert tenant;
    }

    @IsTest
    static void testGetTenantIdByApiKey() {
        Tenant__c tenant = [SELECT Id, API_Key__c FROM Tenant__c LIMIT 1];

        Test.startTest();
        Id resolvedId = TenantContext.getTenantIdByApiKey(tenant.API_Key__c);
        Test.stopTest();

        System.assertEquals(tenant.Id, resolvedId, 'Should resolve correct tenant');
    }

    @IsTest
    static void testGetTenantIdByInvalidKey() {
        Test.startTest();
        Id resolvedId = TenantContext.getTenantIdByApiKey('nonexistent-key');
        Test.stopTest();

        System.assertEquals(null, resolvedId, 'Should return null for invalid key');
    }

    @IsTest
    static void testGetCurrentTenantIdFallback() {
        // No user-tenant mapping, should fallback to first active tenant
        TenantContext.clearCache();

        Test.startTest();
        Id resolvedId = TenantContext.getCurrentTenantId();
        Test.stopTest();

        // Should at least return the test tenant as fallback
        System.assertNotEquals(null, resolvedId, 'Should fallback to active tenant');
    }
}
