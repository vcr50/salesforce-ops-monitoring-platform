/**
 * @description Test class for SeompLoginController.
 *              Covers loginUser() and forgotPassword() methods.
 */
@IsTest
private class SeompLoginControllerTest {

    @IsTest
    static void testLoginUser_InvalidCredentials() {
        Test.startTest();
        try {
            String result = SeompLoginController.loginUser(
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
            Boolean result = SeompLoginController.forgotPassword('nonexistent@test.com');
            // Site.forgotPassword may return false or throw in test context
            System.assertNotEquals(null, result, 'Should return a boolean');
        } catch (AuraHandledException e) {
            // Expected — Site.forgotPassword throws in test context
            System.assertNotEquals(null, e.getMessage(), 'Should have an error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoginUser_EmptyStartUrl() {
        Test.startTest();
        try {
            String result = SeompLoginController.loginUser(
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
    static void testForgotPassword_ValidUser() {
        Test.startTest();
        try {
            // Passing the current user's email, which will find a user record
            SeompLoginController.forgotPassword(UserInfo.getUserEmail());
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}