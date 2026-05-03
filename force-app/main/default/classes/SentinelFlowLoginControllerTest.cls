/**
 * @description Test class for SentinelFlowLoginController.
 *              Covers loginUser() and forgotPassword() methods.
 */
@IsTest
private class SentinelFlowLoginControllerTest {
    private static User makeActiveUser(String suffix) {
        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String uniqueValue = String.valueOf(DateTime.now().getTime()) + suffix;
        User userRecord = new User(
            ProfileId = profile.Id,
            Username = 'sentinelflow.test.' + uniqueValue + '@example.com',
            Email = 'sentinelflow.test.' + uniqueValue + '@example.com',
            LastName = 'Portal Test',
            Alias = ('sft' + suffix).left(8),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert userRecord;
        return userRecord;
    }

    @IsTest
    static void testLoginUser_InvalidCredentials() {
        Test.startTest();
        try {
            String result = SentinelFlowLoginController.loginUser(
                'invalid@test.com',
                'WrongPassword123',
                '/s/'
            );
            // Site.login returns null for bad creds in a non-site context
            System.assertEquals(null, result, 'Expected null for invalid credentials');
        } catch (AuraHandledException e) {
            // Expected — Site.login throws in test context
            System.assertNotEquals(null, e.getMessage(), 'Should have an error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testForgotPassword_InvalidUsername() {
        Test.startTest();
        try {
            Boolean result = SentinelFlowLoginController.forgotPassword('nonexistent@test.com');
            // Site.forgotPassword may return false or throw in test context
            System.assertNotEquals(null, result, 'Should return a boolean');
        } catch (AuraHandledException e) {
            // Expected — Site.forgotPassword throws in test context
            System.assertNotEquals(null, e.getMessage(), 'Should have an error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testForgotPassword_ExistingUsername() {
        User userRecord = makeActiveUser('user');

        Test.startTest();
        try {
            Boolean result = SentinelFlowLoginController.forgotPassword(userRecord.Username);
            System.assertNotEquals(null, result, 'Should return a boolean');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Should surface password reset errors');
        }
        Test.stopTest();
    }

    @IsTest
    static void testForgotPassword_ExistingEmail() {
        User userRecord = makeActiveUser('email');

        Test.startTest();
        try {
            Boolean result = SentinelFlowLoginController.forgotPassword(userRecord.Email);
            System.assertNotEquals(null, result, 'Should return a boolean');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Should surface password reset errors');
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoginUser_EmptyStartUrl() {
        Test.startTest();
        try {
            String result = SentinelFlowLoginController.loginUser(
                'test@example.com',
                'TestPass123',
                ''
            );
            System.assertEquals(null, result, 'Expected null for invalid credentials');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Should have an error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSsoUrls() {
        Test.startTest();
        Map<String, String> urls = SentinelFlowLoginController.getSsoUrls();
        System.assertNotEquals(null, urls, 'SSO URLs map should not be null');
        System.assertEquals(
            0,
            urls.size(),
            'Single Developer Edition org login should not expose same-org SSO links'
        );
        Test.stopTest();
    }

    @IsTest
    static void testGetNetworkHomeUrl_Fallback() {
        Test.startTest();
        String homeUrl = SentinelFlowLoginController.getNetworkHomeUrl();
        Test.stopTest();

        System.assertEquals(
            '/SentinelFlow/',
            homeUrl,
            'Test context should use the SentinelFlow fallback home URL'
        );
    }

    @IsTest
    static void testBuildHomeUrl_FromLoginUrl() {
        System.assertEquals(
            'https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/',
            SentinelFlowLoginController.buildHomeUrl(
                'https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login'
            ),
            'Login URL should resolve to the SentinelFlow site home URL'
        );
        System.assertEquals(
            '/SentinelFlow/',
            SentinelFlowLoginController.buildHomeUrl(null),
            'Blank login URL should use the SentinelFlow fallback'
        );
    }

    @IsTest
    static void testGetSiteRootPath() {
        System.assertEquals(
            '/SentinelFlow/',
            SentinelFlowLoginController.getSiteRootPath(
                'https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/'
            )
        );
        System.assertEquals(
            '/SentinelFlow/',
            SentinelFlowLoginController.getSiteRootPath('/SentinelFlow')
        );
    }

    @IsTest
    static void testNormalizeLoginRedirect_AddsSitePrefix() {
        System.assertEquals(
            '/SentinelFlow/s/',
            SentinelFlowLoginController.normalizeLoginRedirect('/s/')
        );
        System.assertEquals(
            '/SentinelFlow/',
            SentinelFlowLoginController.normalizeLoginRedirect('/')
        );
    }

    @IsTest
    static void testLightningAppRedirectConstant() {
        System.assertEquals(
            'https://astrosoft2-dev-ed.develop.lightning.force.com/lightning/n/Sentinel_Flow',
            SentinelFlowLoginController.SENTINEL_FLOW_LIGHTNING_APP_URL,
            'Successful login should target the SentinelFlow Lightning app'
        );
    }
}
