@IsTest(SeeAllData = true)
public with sharing class LightningLoginFormControllerTest {

 @IsTest
 static void LightningLoginFormControllerInstantiation() {
  LightningLoginFormController controller = new LightningLoginFormController();
  System.assertNotEquals(controller, null);
 }

 @IsTest
 static void testIsUsernamePasswordEnabled() {
  System.assertEquals(true, LightningLoginFormController.getIsUsernamePasswordEnabled());
 }

 @IsTest
 static void testIsSelfRegistrationEnabled() {
  System.assertEquals(false, LightningLoginFormController.getIsSelfRegistrationEnabled());
 }

 @IsTest
 static void testGetSelfRegistrationURL() {
  System.assertEquals(null, LightningLoginFormController.getSelfRegistrationUrl());
 }

 @IsTest
 static void testAuthConfig() {
  Auth.AuthConfiguration authConfig = LightningLoginFormController.getAuthConfig();
  System.assertNotEquals(null, authConfig);
 }

 @IsTest
 static void testLogin() {
  LightningLoginFormController.login('testUser@example.com', 'somePassword', '/home');
  LightningLoginFormController.login('', '', '');
 }

 @IsTest
 static void testGetForgotPasswordUrl() {
  LightningLoginFormController.getForgotPasswordUrl();
 }

 @IsTest
 static void testSetExperienceId() {
  LightningLoginFormController.setExperienceId('testExpId');
  LightningLoginFormController.setExperienceId(null);
 }
}