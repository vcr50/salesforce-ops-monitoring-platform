@IsTest
private class FeatureFlagTest {
    @IsTest
    static void testIsEnabled() {
        System.assertEquals(true, FeatureFlag.isEnabled('AI_ANALYSIS', null));
        System.assertEquals(true, FeatureFlag.isEnabled('AUTO_HEAL', null));
        System.assertEquals(true, FeatureFlag.isEnabled('ANY_OTHER_FLAG', null));
        System.assertEquals(false, FeatureFlag.isEnabled('', null));
        System.assertEquals(true, FeatureFlag.isEnabled('SOME_FLAG'));
    }

    @IsTest
    static void testIsEnabled_Mocked_Tenant() {
        Id fakeTenantId = '001000000000001AAA';
        
        // Mock tenant-specific flag enabled
        String jsonStr = '[{"DeveloperName":"TEST_FLAG", "Is_Enabled__c":true, "Tenant_ID__c":"' + fakeTenantId + '"}]';
        FeatureFlag.mockFlags = (List<Feature_Flag__mdt>) JSON.deserialize(jsonStr, List<Feature_Flag__mdt>.class);
        
        System.assertEquals(true, FeatureFlag.isEnabled('TEST_FLAG', fakeTenantId));
        System.assertEquals(true, FeatureFlag.isEnabled('TEST_FLAG', null), 'Should fallback to global/default');
    }

    @IsTest
    static void testIsEnabled_Mocked_Global() {
        // Mock global flag disabled
        String jsonStr = '[{"DeveloperName":"TEST_FLAG", "Is_Enabled__c":false, "Tenant_ID__c":null}]';
        FeatureFlag.mockFlags = (List<Feature_Flag__mdt>) JSON.deserialize(jsonStr, List<Feature_Flag__mdt>.class);
        
        System.assertEquals(false, FeatureFlag.isEnabled('TEST_FLAG', null));
        System.assertEquals(false, FeatureFlag.isEnabled('TEST_FLAG', '001000000000001AAA'));
    }
}
