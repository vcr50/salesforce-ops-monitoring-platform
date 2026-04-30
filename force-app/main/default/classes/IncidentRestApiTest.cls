/**
 * IncidentRestApiTest
 * Tests the production REST API endpoint for incident creation.
 *
 * @author  Tomcodex
 * @version 1.0
 */
@IsTest
private class IncidentRestApiTest {

    @TestSetup
    static void setupData() {
        Tenant__c tenant = new Tenant__c(
            Name = 'Acme Corp',
            Status__c = 'Active',
            API_Key__c = 'test-api-key-acme-12345'
        );
        insert tenant;
    }

    @IsTest
    static void testPostValidIncident() {
        Tenant__c tenant = [SELECT Id, API_Key__c FROM Tenant__c LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sentinelflow/incidents';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'apiKey' => tenant.API_Key__c,
            'system' => 'Stripe Payment Gateway',
            'error'  => 'Connection timeout after 30s',
            'severity' => 'Critical',
            'usersAffected' => 1200,
            'revenueAtRisk' => 84000
        }));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        IncidentRestApi.doPost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created');

        // Verify incident was persisted
        List<Incident__c> incidents = [
            SELECT Id, Description__c, Severity__c, Tenant__c
            FROM Incident__c
            WHERE Tenant__c = :tenant.Id
        ];
        System.assertEquals(1, incidents.size(), 'One incident should be created');
        System.assertEquals('Critical', incidents[0].Severity__c);
        System.assertEquals(tenant.Id, incidents[0].Tenant__c);

        // Verify integration log was created
        List<Integration_Log__c> logs = [
            SELECT Id, Tenant__c FROM Integration_Log__c
            WHERE Tenant__c = :tenant.Id
        ];
        System.assertEquals(1, logs.size(), 'One integration log should be created');
    }

    @IsTest
    static void testPostMissingFields() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sentinelflow/incidents';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'apiKey' => 'test-api-key-acme-12345'
        }));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        IncidentRestApi.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request');
    }

    @IsTest
    static void testPostInvalidApiKey() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sentinelflow/incidents';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'apiKey' => 'invalid-key-xyz',
            'system' => 'Stripe',
            'error'  => 'timeout'
        }));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        IncidentRestApi.doPost();
        Test.stopTest();

        // Should either create using fallback tenant or return 401
        System.assert(res.statusCode == 201 || res.statusCode == 401,
            'Should fallback to user tenant or return 401');
    }

    @IsTest
    static void testGetIncidents() {
        Tenant__c tenant = [SELECT Id, API_Key__c FROM Tenant__c LIMIT 1];

        // Create test incident
        Incident__c inc = new Incident__c(
            Description__c = 'Test incident',
            Severity__c = 'High',
            Status__c = 'New',
            Tenant__c = tenant.Id
        );
        insert inc;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sentinelflow/incidents';
        req.httpMethod = 'GET';
        req.params.put('apiKey', tenant.API_Key__c);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        IncidentRestApi.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
    }
}
