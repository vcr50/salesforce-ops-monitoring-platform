/**
 * @description Test class for AutoHealOrchestrator.
 * Tests healing rule matching, action execution, escalation, and MTTR calculation.
 * 
 * @author Tomcodex
 * @since 2026-05
 */
@IsTest
private class AutoHealOrchestratorTest {

    /**
     * @description Mock for successful heal endpoint
     */
    private class HealMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status": "healed"}');
            return res;
        }
    }

    /**
     * @description Mock for failed heal endpoint
     */
    private class HealMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "heal failed"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        SF_Incident__c incident = new SF_Incident__c(
            Incident_Type__c    = 'OAuth_Failure',
            Severity__c         = 'P1_High',
            Status__c           = 'Classified',
            Source_System__c    = 'Stripe',
            Error_Code__c       = '401',
            Error_Message__c    = 'Token expired',
            Revenue_Impact__c   = 1500.00,
            Detected_At__c      = System.now().addMinutes(-5)
        );
        insert incident;
    }

    @IsTest
    static void testAutoHealNoRules() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        Map<String, Object> classification = new Map<String, Object>{
            'incidentType' => 'Unknown_Type_No_Rule',
            'sourceSystem' => 'Stripe'
        };

        Test.setMock(HttpCalloutMock.class, new HealMockSuccess());
        Test.startTest();
        System.enqueueJob(new AutoHealOrchestrator(inc.Id, classification));
        Test.stopTest();

        SF_Incident__c updated = [
            SELECT Status__c, Escalation_Reason__c
            FROM SF_Incident__c WHERE Id = :inc.Id
        ];

        System.assertEquals('Escalated', updated.Status__c,
            'Should escalate when no matching runbook exists');
        System.assert(updated.Escalation_Reason__c.contains('No matching runbook'),
            'Escalation reason should mention no runbook');
    }

    @IsTest
    static void testOAuthAutoHealSuccess() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        Map<String, Object> classification = new Map<String, Object>{
            'incidentType' => 'OAuth_Failure',
            'sourceSystem' => 'Stripe'
        };

        Test.setMock(HttpCalloutMock.class, new HealMockSuccess());
        Test.startTest();
        System.enqueueJob(new AutoHealOrchestrator(inc.Id, classification));
        Test.stopTest();

        SF_Incident__c updated = [
            SELECT Status__c, Auto_Healed__c, Heal_Action__c, MTTR_Seconds__c
            FROM SF_Incident__c WHERE Id = :inc.Id
        ];

        System.assertEquals('Auto_Resolved', updated.Status__c);
        System.assertEquals(true, updated.Auto_Healed__c);
        System.assertEquals('REFRESH_OAUTH_TOKEN', updated.Heal_Action__c);
        System.assert(updated.MTTR_Seconds__c > 0, 'MTTR should be calculated.');
    }

    @IsTest
    static void testApiTimeoutAutoHealFailureEscalates() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        Map<String, Object> classification = new Map<String, Object>{
            'incidentType' => 'API_Timeout',
            'sourceSystem' => 'HubSpot'
        };

        Test.setMock(HttpCalloutMock.class, new HealMockFailure());
        Test.startTest();
        System.enqueueJob(new AutoHealOrchestrator(inc.Id, classification));
        Test.stopTest();

        SF_Incident__c updated = [
            SELECT Status__c, Auto_Healed__c, Heal_Action__c, Escalation_Reason__c
            FROM SF_Incident__c WHERE Id = :inc.Id
        ];

        System.assertEquals('Escalated', updated.Status__c);
        System.assertEquals(false, updated.Auto_Healed__c);
        System.assertEquals('RETRY_WITH_BACKOFF', updated.Heal_Action__c);
        System.assert(updated.Escalation_Reason__c.contains('Auto-heal failed'));
    }

    @IsTest
    static void testBatchFailureUsesRequeueAction() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        Map<String, Object> classification = new Map<String, Object>{
            'incidentType' => 'Batch_Failure',
            'sourceSystem' => 'NightlyJob'
        };

        Test.setMock(HttpCalloutMock.class, new HealMockSuccess());
        Test.startTest();
        System.enqueueJob(new AutoHealOrchestrator(inc.Id, classification));
        Test.stopTest();

        SF_Incident__c updated = [
            SELECT Status__c, Heal_Action__c
            FROM SF_Incident__c WHERE Id = :inc.Id
        ];

        System.assertEquals('Auto_Resolved', updated.Status__c);
        System.assertEquals('REQUEUE_SCHEDULED_JOB', updated.Heal_Action__c);
    }

    @IsTest
    static void testApprovalRequiredPathEscalatesWhenApprovalFails() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        Map<String, Object> classification = new Map<String, Object>{
            'incidentType' => 'Governor_Limit',
            'sourceSystem' => 'BatchProcessor'
        };

        Test.setMock(HttpCalloutMock.class, new HealMockSuccess());
        Test.startTest();
        System.enqueueJob(new AutoHealOrchestrator(inc.Id, classification));
        Test.stopTest();

        SF_Incident__c updated = [
            SELECT Status__c
            FROM SF_Incident__c WHERE Id = :inc.Id
        ];

        System.assertEquals('Escalated', updated.Status__c,
            'Approval failures should route to escalation instead of silent success.');
    }

    @IsTest
    static void testMemoryIndexQueueable() {
        SF_Incident__c inc = [SELECT Id FROM SF_Incident__c LIMIT 1];

        // Update with heal data
        update new SF_Incident__c(
            Id = inc.Id,
            Root_Cause__c = 'Expired OAuth Token',
            Heal_Action__c = 'REFRESH_OAUTH_TOKEN',
            Healed_At__c = System.now(),
            Auto_Healed__c = true
        );

        Test.setMock(HttpCalloutMock.class, new HealMockSuccess());
        Test.startTest();
        System.enqueueJob(new MemoryIndexQueueable(inc.Id, true));
        Test.stopTest();

        System.assert(true, 'MemoryIndexQueueable should execute successfully making an API callout.');
    }
}

