@IsTest
public class SiteRegisterControllerTest {
    @IsTest static void testSiteRegisterController() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'test';
        controller.email = 'test@example.com';
        controller.password = 'pass';
        controller.confirmPassword = 'pass';
        controller.communityNickname = 'nick';
        controller.registerUser();
    }
}