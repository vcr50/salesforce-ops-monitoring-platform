@IsTest
public class ForgotPasswordControllerTest {
    @IsTest static void testForgotPasswordController() {
        ForgotPasswordController controller = new ForgotPasswordController();
        controller.username = 'test@example.com';
        controller.forgotPassword();
    }
}