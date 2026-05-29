/**
 * Test class for NetSuiteConnector
 */
@IsTest
private class NetSuiteConnectorTest {

    @IsTest
    static void testSyncToERPSuccess() {
        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'NetSuite',
            Auth_Type__c = 'OAuth 2.0',
            Circuit_Status__c = 'Closed',
            Tenant__c = TenantContext.getCurrentTenantId()
        );
        insert endpoint;

        Test.startTest();
        // Run a couple times to cover logic without hitting SOQL limits
        for (Integer i = 0; i < 2; i++) {
            NetSuiteConnector.syncToERP(null);
        }
        Test.stopTest();
        
        List<Universal_Event__c> events = [SELECT Id, Status__c FROM Universal_Event__c WHERE Source__c = 'NetSuiteConnector'];
        System.assert(events.size() > 0, 'Events should be logged');
    }

    @IsTest
    static void testSyncToERPOpenCircuit() {
        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'NetSuite',
            Auth_Type__c = 'OAuth 2.0',
            Circuit_Status__c = 'Open',
            Tenant__c = TenantContext.getCurrentTenantId()
        );
        insert endpoint;

        Test.startTest();
        NetSuiteConnector.NetSuiteSyncResult result = NetSuiteConnector.syncToERP(null);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Sync should abort if circuit is open');
        System.assert(result.errorMessage.contains('Circuit Breaker is OPEN'));
    }

    @IsTest
    static void testSyncToERPFailureCode() {
        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'NetSuite',
            Auth_Type__c = 'OAuth 2.0',
            Circuit_Status__c = 'Closed',
            Tenant__c = TenantContext.getCurrentTenantId()
        );
        insert endpoint;

        NetSuiteConnector.mockStatusCode = 503;

        Test.startTest();
        NetSuiteConnector.NetSuiteSyncResult result = NetSuiteConnector.syncToERP(null);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assert(result.errorMessage.contains('NetSuite API Error'));
    }

    @IsTest
    static void testSyncToERPException() {
        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'NetSuite',
            Auth_Type__c = 'OAuth 2.0',
            Circuit_Status__c = 'Closed',
            Tenant__c = TenantContext.getCurrentTenantId()
        );
        insert endpoint;

        NetSuiteConnector.forceException = true;

        Test.startTest();
        NetSuiteConnector.NetSuiteSyncResult result = NetSuiteConnector.syncToERP(null);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assert(result.errorMessage.contains('Connection Exception'));
    }
}