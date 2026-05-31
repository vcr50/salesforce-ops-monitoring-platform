@IsTest
private class RateLimiterTest {

    @TestSetup
    static void setup() {
        Tenant__c tenant = new Tenant__c(Name = 'Test Tenant', Status__c = 'Active');
        insert tenant;
    }

    @IsTest
    static void testIsRateLimited_Allow() {
        Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
        
        RateLimiter.mockCacheMap = new Map<String, Integer>();

        Test.startTest();
        Boolean isLimited = RateLimiter.isRateLimited(tenant.Id, 'TestEndpoint');
        Test.stopTest();

        System.assertEquals(false, isLimited, 'Should not be rate limited on first call');
    }

    @IsTest
    static void testIsRateLimited_Block() {
        Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
        
        RateLimiter.mockCacheMap = new Map<String, Integer>();
        
        // Loop to hit the limit
        Test.startTest();
        Boolean isLimited = false;
        for (Integer i = 0; i < 105; i++) {
            isLimited = RateLimiter.isRateLimited(tenant.Id, 'TestEndpoint');
            if (isLimited) break;
        }
        Test.stopTest();

        System.assertEquals(true, isLimited, 'Should be rate limited after exceeding limit');
    }

    @IsTest
    static void testIsRateLimited_Bypass() {
        Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
        
        // Mock FeatureFlag to return false for RATE_LIMITING
        String jsonStr = '[{"DeveloperName":"RATE_LIMITING", "Is_Enabled__c":false, "Tenant_ID__c":null}]';
        FeatureFlag.mockFlags = (List<Feature_Flag__mdt>) JSON.deserialize(jsonStr, List<Feature_Flag__mdt>.class);
        
        Test.startTest();
        Boolean isLimited = RateLimiter.isRateLimited(tenant.Id, 'TestEndpoint');
        Test.stopTest();

        System.assertEquals(false, isLimited, 'Should bypass rate limiting if flag is disabled');
    }

    @IsTest
    static void testIsRateLimited_CacheExceptionFallback() {
        Tenant__c tenant = [SELECT Id FROM Tenant__c LIMIT 1];
        
        // Don't set mockCacheMap so it tries Cache.Org and catches exception in test orgs without cache space
        RateLimiter.mockCacheMap = null;

        Test.startTest();
        Boolean isLimited = RateLimiter.isRateLimited(tenant.Id, 'TestEndpoint');
        Test.stopTest();

        System.assertEquals(false, isLimited, 'Should fail-open and allow request on Cache exception');
    }
}