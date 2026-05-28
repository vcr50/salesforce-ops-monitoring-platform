@IsTest
public class ChangePasswordControllerTest {
    @IsTest static void testChangePasswordController() {
        ChangePasswordController controller = new ChangePasswordController();
        controller.oldPassword = 'old';
        controller.newPassword = 'new';
        controller.verifyNewPassword = 'new';
        controller.changePassword();
    }
}