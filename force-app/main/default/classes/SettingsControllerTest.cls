@isTest
private class SettingsControllerTest {

    @isTest
    static void testLoadAndSaveSettings() {
        // Delete pre-existing defaults to test default fallback deterministically
        SentinelFlow_Settings__c sDel = SentinelFlow_Settings__c.getOrgDefaults();
        if (sDel.Id != null) {
            delete sDel;
        }

        // Test load defaults
        SettingsController.SettingsData data = SettingsController.loadSettings();
        System.assertNotEquals(null, data, 'SettingsData should be loaded');
        Boolean expectedHealing = sDel.Autonomous_Healing__c != null ? sDel.Autonomous_Healing__c : true;
        System.assertEquals(expectedHealing, data.autonomousHealing, 'Autonomous healing should match expected default');

        // Test save retry rules
        Test.startTest();
        SettingsController.saveRetryRules(false, 90, 10, 45, false);
        
        // Test save alert config
        SettingsController.saveAlertConfig(false, '/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX', 'Medium', false);
        Test.stopTest();

        // Verify changes saved
        SentinelFlow_Settings__c s = SentinelFlow_Settings__c.getOrgDefaults();
        System.assertEquals(false, s.Autonomous_Healing__c, 'Autonomous healing should be false');
        System.assertEquals(90, s.Confidence_Threshold__c, 'Confidence threshold should be 90');
        System.assertEquals(10, s.Circuit_Breaker_Threshold__c, 'Circuit breaker threshold should be 10');
        System.assertEquals(45, s.Silent_Failure_Minutes__c, 'Silent failure minutes should be 45');
        System.assertEquals(false, s.Auto_Escalate__c, 'Auto escalate should be false');
        System.assertEquals(false, s.Enable_Alerts__c, 'Enable alerts should be false');
        System.assertEquals('/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX', s.Slack_Webhook_Path__c, 'Slack webhook path mismatch');
        System.assertEquals('Medium', s.Alert_Severity__c, 'Alert severity mismatch');
        System.assertEquals(false, s.Notify_On_Heal__c, 'Notify on heal mismatch');
    }

    @isTest
    static void testSlackWebhookSuccess() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));

        Test.startTest();
        String status = SettingsController.testSlackWebhook('/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX');
        Test.stopTest();

        System.assertEquals('SUCCESS', status, 'Slack test should return SUCCESS');
    }

    @isTest
    static void testSlackWebhookError() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(500, 'Internal Server Error'));

        Test.startTest();
        String status = SettingsController.testSlackWebhook('/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX');
        Test.stopTest();

        System.assert(status.startsWith('ERROR:'), 'Slack test should return ERROR');
    }

    @isTest
    static void testSlackWebhookInvalidPath() {
        Test.startTest();
        String status1 = SettingsController.testSlackWebhook('');
        String status2 = SettingsController.testSlackWebhook('/invalid/path');
        Test.stopTest();

        System.assert(status1.startsWith('ERROR:'), 'Empty path should return ERROR');
        System.assert(status2.startsWith('ERROR:'), 'Invalid path should return ERROR');
    }

    @isTest
    static void testGetCurrencyConfig() {
        Test.startTest();
        Map<String, Object> config = SettingsController.getCurrencyConfig();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Currency config should not be null');
        System.assert(config.containsKey('code'), 'Config should contain code');
        System.assert(config.containsKey('symbol'), 'Config should contain symbol');
        System.assert(config.containsKey('rate'), 'Config should contain rate');
    }

    // HTTP Callout Mock Implementation
    private class SlackMock implements HttpCalloutMock {
        private Integer code;
        private String body;

        public SlackMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}

