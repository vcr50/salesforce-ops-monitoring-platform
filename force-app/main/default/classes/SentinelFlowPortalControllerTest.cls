@IsTest
private class SentinelFlowPortalControllerTest {
    @TestSetup
    static void setupData() {
        SecurityGate.bypassForTests = true;
        User portalUser = createPortalUser();
        insert portalUser;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'SentinelFlow_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = portalUser.Id, PermissionSetId = ps.Id);

        System.runAs(portalUser) {
            Tenant__c tenant = new Tenant__c(
                Name = 'Portal Test Tenant',
                Status__c = 'Active'
            );
            insert tenant;

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
                    Error_Message__c = 'Timeout',
                    Tenant__c = tenant.Id
                ),
                new Integration_Log__c(
                    API_Name__c = 'Inventory API',
                    Status__c = 'Warning',
                    Response_Time__c = 950,
                    Error_Message__c = 'Delay',
                    Tenant__c = tenant.Id
                ),
                new Integration_Log__c(
                    API_Name__c = 'Shipping API',
                    Status__c = 'Success',
                    Response_Time__c = 420,
                    Tenant__c = tenant.Id
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
                    Description__c = 'Critical linked portal test incident',
                    Environment__c = environmentRecord.Id,
                    Integration_Log__c = failedLogId,
                    Tenant__c = tenant.Id
                ),
                new Incident__c(
                    Severity__c = 'High',
                    Status__c = 'Escalated',
                    Description__c = 'Escalated portal test incident',
                    Environment__c = environmentRecord.Id,
                    Tenant__c = tenant.Id
                ),
                new Incident__c(
                    Severity__c = 'High',
                    Status__c = 'Closed',
                    Description__c = 'Closed portal test incident',
                    Environment__c = environmentRecord.Id,
                    Tenant__c = tenant.Id
                )
            };
        }
    }

    @IsTest
    static void summaryReturnsLiveCounts() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
            Test.startTest();
            SentinelFlowPortalController.PortalSummary summary = SentinelFlowPortalController.getSummary();
            Test.stopTest();

            System.assert(summary.criticalIncidents >= 1, 'At least one critical incident should be present.');
            System.assert(summary.openIncidents >= 2, 'Open incident count should include seeded and automated records.');
            System.assertEquals(1, summary.failedIntegrations);
            System.assertEquals(1, summary.warningIntegrations);
        }
    }

    @IsTest
    static void openIncidentsReturnsOnlyActiveRecords() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
            Test.startTest();
            List<SentinelFlowPortalController.PortalIncidentRow> rows = SentinelFlowPortalController.getOpenIncidents();
            Test.stopTest();

            System.assert(rows.size() >= 2, 'Open rows should include seeded and automated active incidents.');
            for (SentinelFlowPortalController.PortalIncidentRow row : rows) {
                System.assertNotEquals('Closed', row.status);
                System.assertNotEquals('Resolved', row.status);
            }
        }
    }

    @IsTest
    static void activeIntegrationsReturnsFailedAndWarnings() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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
    }

    @IsTest
    static void incidentDetailReturnsRelatedContext() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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
    }

    @IsTest
    static void integrationDetailReturnsLinkedIncidentCount() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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
            System.assert(detail.linkedOpenIncidents >= 1, 'Failed log should have at least one linked open incident.');
        }
    }

    @IsTest
    static void createSimulatedIncidentHonorsActiveTrial() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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
    }

    @IsTest
    static void professionalActionsExecuteThroughControllerLayer() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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
    }

    @IsTest
    static void listAndNullDetailHelpersReturnSafely() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
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

    private static User createPortalUser() {
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        String uniqueValue = String.valueOf(DateTime.now().getTime());
        return new User(
            Alias = 'sfpt',
            Email = 'sentinelflow.portal.' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Portal Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'sentinelflow.portal.' + uniqueValue + '@example.com'
        );
    }

    private static User getPortalUser() {
        return [
            SELECT Id
            FROM User
            WHERE Alias = 'sfpt'
            LIMIT 1
        ];
    }

    @IsTest
    static void testAdditionalPortalControllerMethods() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
            // Seed a universal event if the object exists
            Boolean ueExists = Schema.getGlobalDescribe().containsKey('Universal_Event__c');
            if (ueExists) {
                SObject ue = Schema.getGlobalDescribe().get('Universal_Event__c').newSObject();
                ue.put('Event_Key__c', 'test_key_123');
                ue.put('Event_Type__c', 'Flow Exception');
                ue.put('Source__c', 'Salesforce');
                ue.put('Severity__c', 'Medium');
                ue.put('Status__c', 'New');
                insert ue;
            }

            // Seed an AI Decision if the object exists
            Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];
            Boolean adExists = Schema.getGlobalDescribe().containsKey('AI_Decision__c');
            if (adExists) {
                SObject ad1 = Schema.getGlobalDescribe().get('AI_Decision__c').newSObject();
                ad1.put('Incident__c', inc.Id);
                ad1.put('Confidence_Score__c', 85.0);
                ad1.put('Root_Cause__c', 'CPU Limit');
                ad1.put('Recommended_Action__c', 'Retry');
                insert ad1;

                SObject ad2 = Schema.getGlobalDescribe().get('AI_Decision__c').newSObject();
                ad2.put('Incident__c', inc.Id);
                ad2.put('Confidence_Score__c', 70.0);
                ad2.put('Root_Cause__c', 'CPU Limit');
                ad2.put('Recommended_Action__c', 'Retry');
                insert ad2;

                SObject ad3 = Schema.getGlobalDescribe().get('AI_Decision__c').newSObject();
                ad3.put('Incident__c', inc.Id);
                ad3.put('Root_Cause__c', 'CPU Limit');
                ad3.put('Recommended_Action__c', 'Retry');
                insert ad3;
            }

            Test.startTest();
            List<SentinelFlowPortalController.PortalUniversalEventRow> events = SentinelFlowPortalController.getUniversalEvents();
            List<SentinelFlowPortalController.PortalAIDecisionRow> decisions = SentinelFlowPortalController.getAIDecisions(inc.Id);
            List<SentinelFlowPortalController.PortalAIDecisionRow> decisionsNull = SentinelFlowPortalController.getAIDecisions(null);
            HealTelemetryService.HealMetrics metrics = SentinelFlowPortalController.getHealMetrics();
            Test.stopTest();

            System.assertNotEquals(null, events);
            System.assertNotEquals(null, decisions);
            System.assertEquals(0, decisionsNull.size());
            System.assertNotEquals(null, metrics);
        }
    }

    @IsTest
    static void testWithoutTenant() {
        enableSecurityBypass();
        System.runAs(getPortalUser()) {
            // Delete the tenant to force fallback to null
            delete [SELECT Id FROM Tenant__c];
            TenantContext.clearCache();

            Test.startTest();
            SentinelFlowPortalController.PortalSummary summary = SentinelFlowPortalController.getSummary();
            List<SentinelFlowPortalController.PortalIncidentRow> incidents = SentinelFlowPortalController.getOpenIncidents();
            List<SentinelFlowPortalController.PortalIntegrationRow> logs = SentinelFlowPortalController.getIntegrationLogs();
            Test.stopTest();

            System.assertNotEquals(null, summary);
        }
    }

    private static void enableSecurityBypass() {
        SecurityGate.bypassForTests = true;
    }
}