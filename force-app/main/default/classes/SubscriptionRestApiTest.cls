@IsTest
private class SubscriptionRestApiTest {
    @IsTest
    static void postUpdatesSubscription() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/subscription/update';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'orgId' => '00D000000000003AAA',
            'plan' => 'Professional',
            'status' => 'Active',
            'expiryDate' => String.valueOf(Date.today().addMonths(1)),
            'stripeCustomerId' => 'cus_123',
            'stripeSubscriptionId' => 'sub_123',
            'eventName' => 'invoice.paid'
        }));

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        SubscriptionRestApi.doPost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Subscription__c subscription = [
            SELECT Plan__c, Status__c, Stripe_Customer_Id__c, Stripe_Subscription_Id__c
            FROM Subscription__c
            WHERE Org_Id__c = '00D000000000003AAA'
            LIMIT 1
        ];
        System.assertEquals('Professional', subscription.Plan__c);
        System.assertEquals('Active', subscription.Status__c);
        System.assertEquals('cus_123', subscription.Stripe_Customer_Id__c);
        System.assertEquals('sub_123', subscription.Stripe_Subscription_Id__c);
    }

    @IsTest
    static void postRequiresOrgId() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/subscription/update';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"plan":"Professional"}');

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        SubscriptionRestApi.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}
