@IsTest
private class ZentomActionsTest {

    @TestSetup
    static void setup() {
        // Setup base data
        Tenant__c tenant = new Tenant__c(Name = 'Test Tenant Actions', Status__c = 'Active');
        insert tenant;

        Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
            Name = 'Test Endpoint Actions',
            Circuit_Status__c = 'Closed',
            Failure_Count__c = 0
        );
        insert endpoint;

        Integration_Log__c log = new Integration_Log__c(
            API_Name__c = 'SAP ERP',
            Status__c   = 'Failed',
            Error_Message__c = 'Timeout',
            Tenant__c   = tenant.Id
        );
        insert log;
        
        // Delete the auto-created incident from the log trigger to avoid conflicts
        delete [SELECT Id FROM Incident__c];

        Incident__c inc1 = new Incident__c(
            Severity__c        = 'High',
            Status__c          = 'New',
            Integration_Log__c = log.Id,
            Integration_Endpoint__c = endpoint.Id,
            Tenant__c          = tenant.Id,
            Retry_Count__c     = 0,
            Self_Heal_Attempted__c = false,
            Description__c     = 'Test incident High',
            Error_Type__c      = 'FLOW_FAILURE',
            Revenue_at_Risk__c = 1000
        );
        insert inc1;

        Incident__c inc2 = new Incident__c(
            Severity__c        = 'Critical',
            Status__c          = 'New',
            Tenant__c          = tenant.Id,
            Retry_Count__c     = 0,
            Self_Heal_Attempted__c = false,
            Description__c     = 'Test incident Critical',
            Error_Type__c      = 'API_TIMEOUT',
            Revenue_at_Risk__c = 60000
        );
        insert inc2;
    }

    @IsTest
    static void testGetIncidentsAction() {
        SecurityGate.bypassForTests = true;

        // Test with empty request list
        List<ZentomGetIncidentsAction.IncidentResult> resultsEmpty = ZentomGetIncidentsAction.getOpenIncidents(new List<ZentomGetIncidentsAction.IncidentRequest>());
        System.assertNotEquals(null, resultsEmpty);

        // Test with severity filter
        ZentomGetIncidentsAction.IncidentRequest req = new ZentomGetIncidentsAction.IncidentRequest();
        req.severity = 'High';

        Test.startTest();
        List<ZentomGetIncidentsAction.IncidentResult> results = ZentomGetIncidentsAction.getOpenIncidents(new List<ZentomGetIncidentsAction.IncidentRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(1, results[0].incidents.size());
        System.assertEquals('High', results[0].incidents[0].Severity__c);
    }

    @IsTest
    static void testGetIncidentDetailsAction() {
        SecurityGate.bypassForTests = true;

        List<Incident__c> incs = [SELECT Id, Severity__c FROM Incident__c];
        List<ZentomGetIncidentDetailsAction.IncidentDetailRequest> reqs = new List<ZentomGetIncidentDetailsAction.IncidentDetailRequest>();
        for (Incident__c inc : incs) {
            ZentomGetIncidentDetailsAction.IncidentDetailRequest req = new ZentomGetIncidentDetailsAction.IncidentDetailRequest();
            req.incidentId = inc.Id;
            reqs.add(req);
        }

        // Test with empty request
        List<ZentomGetIncidentDetailsAction.IncidentDetailResult> resultsEmpty = ZentomGetIncidentDetailsAction.getIncidentDetails(null);
        System.assertEquals(0, resultsEmpty.size());

        Test.startTest();
        List<ZentomGetIncidentDetailsAction.IncidentDetailResult> results = ZentomGetIncidentDetailsAction.getIncidentDetails(reqs);
        Test.stopTest();

        System.assertEquals(2, results.size());
        
        // Assert that the incident detail contains technical logs and revenue details
        Boolean foundHigh = false;
        Boolean foundCritical = false;
        for (ZentomGetIncidentDetailsAction.IncidentDetailResult res : results) {
            if (res.incidentName != null) {
                if (res.revenueRisk == 1000) {
                    foundHigh = true;
                    System.assert(res.technicalLog.contains('API Name: SAP ERP'), 'Should print API Name');
                } else if (res.revenueRisk == 60000) {
                    foundCritical = true;
                    System.assert(res.technicalLog.contains('AI GUARDIAN CONTEXT'), 'Should print AI Guardian context');
                }
            }
        }
        System.assert(foundHigh, 'Should find high severity incident details');
        System.assert(foundCritical, 'Should find critical severity incident details');
    }

    @IsTest
    static void testHealIncidentAction() {
        SecurityGate.bypassForTests = true;

        Incident__c inc = [SELECT Id FROM Incident__c WHERE Severity__c = 'High' LIMIT 1];
        inc.Recommended_Action__c = 'Retry';
        inc.Retry_Count__c = 0;
        inc.Self_Heal_Attempted__c = false;
        update inc;

        ZentomHealIncidentAction.HealRequest req = new ZentomHealIncidentAction.HealRequest();
        req.incidentId = inc.Id;

        Test.startTest();
        List<ZentomHealIncidentAction.HealResultOutput> results = ZentomHealIncidentAction.executeAutoHeal(new List<ZentomHealIncidentAction.HealRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assert(results[0].message.contains('Retry #1 executed'), 'Message should indicate retry: ' + results[0].message);
    }
}
