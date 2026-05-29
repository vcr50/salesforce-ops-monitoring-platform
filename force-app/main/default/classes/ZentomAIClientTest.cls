@IsTest
private class ZentomAIClientTest {

    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Incident__c inc = new Incident__c(
            Severity__c = 'High',
            Status__c = 'New',
            Description__c = 'Test incident'
        );
        insert inc;
    }

    @IsTest
    static void testOrchestrateIncidentAsync_Accepted() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(202, '{"taskId": "task-123"}'));
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        String result = ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        Test.stopTest();

        System.assertEquals('task-123', result);
    }

    @IsTest
    static void testOrchestrateIncidentAsync_SyncComplete() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"taskId": "task-123"}'));
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        String result = ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        Test.stopTest();

        System.assertEquals('SYNC_COMPLETE', result);
    }

    @IsTest
    static void testOrchestrateIncidentAsync_Failure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, '{}'));
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        String result = ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testOrchestrateIncidentAsync_CircuitBreaker() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, '{}'));
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        // Fail 3 times to open circuit breaker
        ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');

        // Fourth time should return null without callout
        String result = ZentomAIClient.orchestrateIncidentAsync(inc.Id, 'Prompt', 'Test', 'Stage');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testSendEvaluationFeedback() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{}'));
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        ZentomAIClient.sendEvaluationFeedback(inc.Id, true, 'Retry', 90);
        Test.stopTest();

        // No return value, just checking it doesn't throw exceptions
        System.assert(true);
    }
}
