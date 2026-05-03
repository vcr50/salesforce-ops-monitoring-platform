@IsTest
private class SlackNotificationTest {

    /**
     * Mock HTTP callout that simulates a successful Slack webhook response.
     */
    private class SlackSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    /**
     * Mock HTTP callout that simulates a Slack webhook failure.
     */
    private class SlackFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('invalid_payload');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        SentinelFlow_Settings__c settings = new SentinelFlow_Settings__c(
            Enable_Alerts__c = true,
            Endpoint_Active__c = true,
            Max_Retry__c = 3
        );
        insert settings;

        // Create a test Tenant
        Tenant__c tenant = new Tenant__c(
            Name = 'Test Tenant',
            Slack_Webhook_Path__c = '/services/TTEST/BTEST/testwebhook'
        );
        insert tenant;

        // Create a test Incident
        Incident__c inc = new Incident__c(
            Severity__c   = 'Critical',
            Status__c     = 'Open',
            Description__c = 'Test incident for Slack alert',
            Users_Affected__c = 50,
            Revenue_at_Risk__c = 5000,
            Tenant__c     = tenant.Id
        );
        insert inc;
    }

    @IsTest
    static void testSendSlackAlert_Success() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());
        Test.startTest();
        NotificationService.sendSlackAlert(inc.Id);
        Test.stopTest();

        // Verify audit log was created for successful send
        List<Audit_Trail__c> logs = [
            SELECT Action__c FROM Audit_Trail__c
            WHERE Record_Id__c = :inc.Id AND Action__c = 'Slack Alert Sent'
        ];
        System.assertEquals(1, logs.size(), 'Should have one Slack Alert Sent audit log entry');
    }

    @IsTest
    static void testSendSlackAlert_HttpError() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SlackFailMock());
        Test.startTest();
        NotificationService.sendSlackAlert(inc.Id);
        Test.stopTest();

        // Even on 400, an audit log should be recorded
        List<Audit_Trail__c> logs = [
            SELECT Action__c FROM Audit_Trail__c
            WHERE Record_Id__c = :inc.Id AND Action__c = 'Slack Alert Failed'
        ];
        System.assert(logs.size() >= 1, 'Should log even on non-200 response');
    }

    @IsTest
    static void testSendSlackAlert_NullInputs() {
        Test.startTest();
        // Should be graceful no-ops
        NotificationService.sendSlackAlert(null);
        Test.stopTest();
        // No exception thrown = pass
        System.assert(true, 'Null/blank inputs should not throw exceptions');
    }
}
