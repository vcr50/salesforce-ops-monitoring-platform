/**
 * UniversalEventWebhookApiTest
 * Test coverage for UniversalEventWebhookApi.
 * Validates Stripe, Shopify, and HubSpot webhook parsing into Universal_Event__c.
 */
@IsTest
private class UniversalEventWebhookApiTest {

    @IsTest
    static void testStripeWebhook() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sentinelflow/webhook/stripe';
        req.httpMethod = 'POST';
        
        String payload = '{' +
            '"id": "evt_12345",' +
            '"type": "invoice.payment_failed",' +
            '"data": {' +
                '"object": {' +
                    '"amount_due": 150000' +
                '}' +
            '}' +
        '}';
        
        req.requestBody = Blob.valueOf(payload);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        UniversalEventWebhookApi.doPost();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
        
        List<Universal_Event__c> events = [SELECT Id, Source__c, Revenue_Risk__c, Severity__c FROM Universal_Event__c];
        System.assertEquals(1, events.size(), 'Should create one Stripe event');
        System.assertEquals('Stripe', events[0].Source__c);
        System.assertEquals(1500, events[0].Revenue_Risk__c, 'Amount should be divided by 100');
        System.assertEquals('Critical', events[0].Severity__c);
    }

    @IsTest
    static void testShopifyWebhook() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sentinelflow/webhook/shopify';
        req.httpMethod = 'POST';
        
        String payload = '{' +
            '"id": 820982911946154508,' +
            '"total_price": "299.00"' +
        '}';
        
        req.requestBody = Blob.valueOf(payload);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        UniversalEventWebhookApi.doPost();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode);
        
        List<Universal_Event__c> events = [SELECT Id, Source__c, Revenue_Risk__c, Workflow_Stage__c FROM Universal_Event__c WHERE Source__c = 'Shopify'];
        System.assertEquals(1, events.size());
        System.assertEquals(299.00, events[0].Revenue_Risk__c);
        System.assertEquals('Fulfillment', events[0].Workflow_Stage__c);
    }
    
    @IsTest
    static void testHubSpotWebhook() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sentinelflow/webhook/hubspot';
        req.httpMethod = 'POST';
        
        String payload = '[' +
            '{' +
                '"eventId": 1001,' +
                '"subscriptionType": "contact.deletion"' +
            '},' +
            '{' +
                '"eventId": 1002,' +
                '"subscriptionType": "contact.creation"' +
            '}' +
        ']';
        
        req.requestBody = Blob.valueOf(payload);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        UniversalEventWebhookApi.doPost();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode);
        
        // Should only process the deletion event based on the logic
        List<Universal_Event__c> events = [SELECT Id, Source__c, Source_Record_Id__c FROM Universal_Event__c WHERE Source__c = 'HubSpot'];
        System.assertEquals(1, events.size());
        System.assertEquals('1001', events[0].Source_Record_Id__c);
    }
    
    @IsTest
    static void testInvalidProvider() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sentinelflow/webhook/unknown';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        UniversalEventWebhookApi.doPost();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode);
    }
}

