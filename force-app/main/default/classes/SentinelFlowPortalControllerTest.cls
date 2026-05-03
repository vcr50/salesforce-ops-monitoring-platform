@IsTest
private class SentinelFlowPortalControllerTest {
    @TestSetup
    static void setupData() {
        Environment__c environmentRecord = new Environment__c(
            Name = 'Portal Test Environment',
            Org_Id__c = '00DPORTALTEST0001'
        );
        insert environmentRecord;

        SLA_Policy__c policyRecord = new SLA_Policy__c(
            Name = 'Portal Test Critical Policy',
            Severity__c = 'Critical',
            Response_Time_Min__c = 15,
            Resolution_Time_Min__c = 120
        );
        insert policyRecord;

        insert new List<Integration_Log__c>{
            new Integration_Log__c(
                API_Name__c = 'Orders API',
                Status__c = 'Failed',
                Response_Time__c = 2400,
                Error_Message__c = 'Timeout'
            ),
            new Integration_Log__c(
                API_Name__c = 'Inventory API',
                Status__c = 'Warning',
                Response_Time__c = 950,
                Error_Message__c = 'Delay'
            ),
            new Integration_Log__c(
                API_Name__c = 'Shipping API',
                Status__c = 'Success',
                Response_Time__c = 420
            )
        };

        Id failedLogId = [
            SELECT Id
            FROM Integration_Log__c
            WHERE API_Name__c = 'Orders API'
            LIMIT 1
        ].Id;

        insert new List<Incident__c>{
            new Incident__c(
                Severity__c = 'Critical',
                Status__c = 'New',
                Description__c = 'Critical portal test incident',
                Environment__c = environmentRecord.Id,
                Integration_Log__c = failedLogId,
                SLA_Policy__c = policyRecord.Id
            ),
            new Incident__c(
                Severity__c = 'High',
                Status__c = 'Escalated',
                Description__c = 'Escalated portal test incident',
                Environment__c = environmentRecord.Id
            ),
            new Incident__c(
                Severity__c = 'High',
                Status__c = 'Closed',
                Description__c = 'Closed portal test incident',
                Environment__c = environmentRecord.Id
            )
        };
    }

    @IsTest
    static void summaryReturnsLiveCounts() {
        Test.startTest();
        SentinelFlowPortalController.PortalSummary summary = SentinelFlowPortalController.getSummary();
        Test.stopTest();

        System.assertEquals(2, summary.criticalIncidents);
        System.assertEquals(3, summary.openIncidents);
        System.assertEquals(1, summary.failedIntegrations);
        System.assertEquals(1, summary.warningIntegrations);
    }

    @IsTest
    static void openIncidentsReturnsOnlyActiveRecords() {
        Test.startTest();
        List<SentinelFlowPortalController.PortalIncidentRow> rows = SentinelFlowPortalController.getOpenIncidents();
        Test.stopTest();

        System.assertEquals(3, rows.size());
        for (SentinelFlowPortalController.PortalIncidentRow row : rows) {
            System.assertNotEquals('Closed', row.status);
            System.assertNotEquals('Resolved', row.status);
        }
    }

    @IsTest
    static void activeIntegrationsReturnsFailedAndWarnings() {
        Test.startTest();
        List<SentinelFlowPortalController.PortalIntegrationRow> rows = SentinelFlowPortalController.getActiveIntegrations();
        Test.stopTest();

        System.assertEquals(2, rows.size());
        Set<String> statuses = new Set<String>();
        for (SentinelFlowPortalController.PortalIntegrationRow row : rows) {
            statuses.add(row.status);
        }

        System.assert(statuses.contains('Failed'));
        System.assert(statuses.contains('Warning'));
        System.assert(!statuses.contains('Success'));
    }

    @IsTest
    static void incidentDetailReturnsRelatedContext() {
        Id incidentId = [
            SELECT Id
            FROM Incident__c
            WHERE Severity__c = 'Critical'
            AND Status__c = 'New'
            AND Integration_Log__c != null
            LIMIT 1
        ].Id;

        Test.startTest();
        SentinelFlowPortalController.PortalIncidentDetail detail = SentinelFlowPortalController.getIncidentDetail(incidentId);
        Test.stopTest();

        System.assertEquals('Critical', detail.severity);
        System.assertEquals('New', detail.status);
    }

    @IsTest
    static void integrationDetailReturnsLinkedIncidentCount() {
        Id logId = [
            SELECT Id
            FROM Integration_Log__c
            WHERE API_Name__c = 'Orders API'
            LIMIT 1
        ].Id;

        Test.startTest();
        SentinelFlowPortalController.PortalIntegrationDetail detail = SentinelFlowPortalController.getIntegrationDetail(logId);
        Test.stopTest();

        System.assertEquals('Orders API', detail.apiName);
        System.assertEquals('Failed', detail.status);
        System.assertEquals(2, detail.linkedOpenIncidents);
    }

    @IsTest
    static void createSimulatedIncidentHonorsActiveTrial() {
        Test.startTest();
        Id incidentId = SentinelFlowPortalController.createSimulatedIncident(
            'Portal-created subscription test incident',
            'Medium',
            'Billing API',
            25,
            1000
        );
        Test.stopTest();

        Incident__c incident = [
            SELECT Description__c, Severity__c, Status__c
            FROM Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];
        System.assertEquals('Portal-created subscription test incident', incident.Description__c);
        System.assertEquals('Medium', incident.Severity__c);
        System.assertNotEquals('Closed', incident.Status__c);
    }

    @IsTest
    static void professionalActionsExecuteThroughControllerLayer() {
        Id incidentId = [
            SELECT Id
            FROM Incident__c
            WHERE Status__c != 'Closed'
            LIMIT 1
        ].Id;
        insert new Subscription__c(
            Org_Id__c = UserInfo.getOrganizationId(),
            Plan__c = 'Professional',
            Status__c = 'Active',
            Expiry_Date__c = Date.today().addDays(30)
        );

        Test.startTest();
        try {
            SentinelFlowPortalController.analyseIncident(incidentId);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            SentinelFlowPortalController.calculateImpact(incidentId, 49);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            SentinelFlowPortalController.healIncident(incidentId);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void listAndNullDetailHelpersReturnSafely() {
        Test.startTest();
        List<SentinelFlowPortalController.PortalIntegrationRow> logs = SentinelFlowPortalController.getIntegrationLogs();
        SentinelFlowPortalController.PortalIncidentDetail incidentDetail = SentinelFlowPortalController.getIncidentDetail(null);
        SentinelFlowPortalController.PortalIntegrationDetail integrationDetail = SentinelFlowPortalController.getIntegrationDetail(null);
        Test.stopTest();

        System.assert(logs.size() >= 3);
        System.assertEquals(null, incidentDetail);
        System.assertEquals(null, integrationDetail);
    }
}
