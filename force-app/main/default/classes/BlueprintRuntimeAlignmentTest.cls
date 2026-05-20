@IsTest
private class BlueprintRuntimeAlignmentTest {
    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setStatus('OK');
            response.setBody('{"status":"ok"}');
            return response;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(503);
            response.setStatus('Service Unavailable');
            response.setBody('{"error":"downstream unavailable"}');
            return response;
        }
    }

    private class FailingConnector extends ExternalIntelligenceConnector {
        public override String getConnectorName() {
            return 'Blueprint Test Connector';
        }

        public override String getNamedCredential() {
            return 'SentinelFlow_Backend';
        }

        public override String mapRevenueImpact(Integration_Log__c logRecord) {
            return 'Revenue impact requires operator review.';
        }
    }

    @TestSetup
    static void setupData() {
        SecurityGate.bypassForTests = true;

        Tenant__c tenant = new Tenant__c(Name = 'Blueprint Tenant', Status__c = 'Active');
        insert tenant;

        insert new Integration_Endpoint__c(
            Name = 'Blueprint Endpoint',
            Active__c = true,
            Circuit_Status__c = 'Closed',
            Failure_Count__c = 0,
            Tenant__c = tenant.Id
        );
    }

    @IsTest
    static void flowFailureCreatesHealthIncidentAndEventPath() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        FlowHealthMonitor.registerFlowFailure('Order_Fulfillment', 'Order Fulfillment', 'Fault route failed', 3);
        Test.stopTest();

        Flow_Health__c health = [
            SELECT Flow_API_Name__c, Last_Run_Status__c, Failure_Count__c, Affected_Records__c
            FROM Flow_Health__c
            WHERE Flow_API_Name__c = 'Order_Fulfillment'
            LIMIT 1
        ];
        System.assertEquals('Failed', health.Last_Run_Status__c);
        System.assertEquals(1, health.Failure_Count__c);
        System.assertEquals(3, health.Affected_Records__c);

        List<Incident__c> incidents = [
            SELECT Description__c
            FROM Incident__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        Boolean foundFlowIncident = false;
        for (Incident__c incidentRecord : incidents) {
            foundFlowIncident = foundFlowIncident
                || (incidentRecord.Description__c != null
                    && incidentRecord.Description__c.startsWith('Flow execution failure detected'));
        }
        System.assert(foundFlowIncident, 'Expected the flow failure to create a SentinelFlow incident.');
    }

    @IsTest
    static void connectorLogsEndpointAndResponseCode() {
        SecurityGate.bypassForTests = true;
        Test.setMock(HttpCalloutMock.class, new OkMock());

        Integration_Endpoint__c endpoint = [
            SELECT Id
            FROM Integration_Endpoint__c
            LIMIT 1
        ];

        Test.startTest();
        Integration_Log__c logRecord = new FailingConnector().executeMonitoredCall(endpoint.Id, '/health');
        Test.stopTest();

        Integration_Log__c savedLog = [
            SELECT Status__c, Response_Code__c, Integration_Endpoint__c
            FROM Integration_Log__c
            WHERE Id = :logRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Success', savedLog.Status__c);
        System.assertEquals(200, savedLog.Response_Code__c);
        System.assertEquals(endpoint.Id, savedLog.Integration_Endpoint__c);
    }

    @IsTest
    static void connectorFailureCreatesIncidentAndUpdatesCircuit() {
        SecurityGate.bypassForTests = true;
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Integration_Endpoint__c endpoint = [
            SELECT Id
            FROM Integration_Endpoint__c
            LIMIT 1
        ];

        Test.startTest();
        new FailingConnector().executeMonitoredCall(endpoint.Id, '/health');
        Test.stopTest();

        Integration_Log__c savedLog = [
            SELECT Status__c, Response_Code__c
            FROM Integration_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Failed', savedLog.Status__c);
        System.assertEquals(503, savedLog.Response_Code__c);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Incident__c
                WHERE Integration_Log__c = :savedLog.Id
            ]
        );
    }

    @IsTest
    static void connectorStopsWhenCircuitIsOpen() {
        SecurityGate.bypassForTests = true;

        Integration_Endpoint__c endpoint = [
            SELECT Id, Circuit_Status__c
            FROM Integration_Endpoint__c
            LIMIT 1
        ];
        endpoint.Circuit_Status__c = 'Open';
        update endpoint;

        try {
            new FailingConnector().executeMonitoredCall(endpoint.Id, '/health');
            System.assert(false, 'Expected an open circuit to block the monitored call.');
        } catch (ConnectorBase.ConnectorException expected) {
            System.assert(expected.getMessage().contains('circuit is open'));
        }
    }

    @IsTest
    static void connectorCanLogWithoutEndpointContext() {
        SecurityGate.bypassForTests = true;
        Test.setMock(HttpCalloutMock.class, new OkMock());

        Test.startTest();
        Integration_Log__c logRecord = new FailingConnector().executeMonitoredCall(null, '/health');
        Test.stopTest();

        Integration_Log__c savedLog = [
            SELECT Status__c, Integration_Endpoint__c
            FROM Integration_Log__c
            WHERE Id = :logRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Success', savedLog.Status__c);
        System.assertEquals(null, savedLog.Integration_Endpoint__c);
    }

    @IsTest
    static void guardianSweepCanBeScheduledOnce() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        String firstJobId = FlowHealthSchedulable.scheduleEveryFifteenMinutes();
        String secondJobId = FlowHealthSchedulable.scheduleEveryFifteenMinutes();
        Test.stopTest();

        System.assert(String.valueOf(secondJobId).startsWith(String.valueOf(firstJobId)));
        System.assertEquals(
            4,
            [
                SELECT COUNT()
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'SentinelFlow Guardian Sweep%'
            ]
        );
    }

    @IsTest
    static void securityGateBypassAndFailurePathsAreCovered() {
        SecurityGate.bypassForTests = true;
        SecurityGate.requireAccessible('Incident__c');
        SecurityGate.requireCreateable('Incident__c');
        SecurityGate.requireUpdateable('Incident__c');
        SecurityGate.requireDeletable('Incident__c');
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{'Id'});
        SecurityGate.requireCreateAccess('Incident__c', new Set<String>{'Status__c'});
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{'Status__c'});
        SecurityGate.requireDeleteAccess('Incident__c');
        System.assert(SecurityGate.isAccessible('Incident__c'));
        System.assert(SecurityGate.isCreateable('Incident__c'));
        System.assert(SecurityGate.isUpdateable('Incident__c'));
        System.assert(SecurityGate.isDeletable('Incident__c'));

        SecurityGate.bypassForTests = false;
        System.assertEquals(false, SecurityGate.isAccessible('Missing_Object__c'));
        System.assertEquals(false, SecurityGate.isCreateable('Missing_Object__c'));
        System.assertEquals(false, SecurityGate.isUpdateable('Missing_Object__c'));
        System.assertEquals(false, SecurityGate.isDeletable('Missing_Object__c'));

        assertSecurityException(new SecurityRunnable('accessible'));
        assertSecurityException(new SecurityRunnable('createable'));
        assertSecurityException(new SecurityRunnable('updateable'));
        assertSecurityException(new SecurityRunnable('deletable'));
        assertSecurityException(new SecurityRunnable('readFields'));
        assertSecurityException(new SecurityRunnable('createFields'));
        assertSecurityException(new SecurityRunnable('updateFields'));
        assertSecurityException(new SecurityRunnable('deleteAccess'));
    }

    private class SecurityRunnable {
        private String mode;

        SecurityRunnable(String mode) {
            this.mode = mode;
        }

        void run() {
            if (mode == 'accessible') {
                SecurityGate.requireAccessible('Missing_Object__c');
            } else if (mode == 'createable') {
                SecurityGate.requireCreateable('Missing_Object__c');
            } else if (mode == 'updateable') {
                SecurityGate.requireUpdateable('Missing_Object__c');
            } else if (mode == 'deletable') {
                SecurityGate.requireDeletable('Missing_Object__c');
            } else if (mode == 'readFields') {
                SecurityGate.requireReadAccess('Incident__c', new Set<String>{'Missing_Field__c'});
            } else if (mode == 'createFields') {
                SecurityGate.requireCreateAccess('Incident__c', new Set<String>{'Missing_Field__c'});
            } else if (mode == 'updateFields') {
                SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{'Missing_Field__c'});
            } else if (mode == 'deleteAccess') {
                SecurityGate.requireDeleteAccess('Missing_Object__c');
            }
        }
    }

    private static void assertSecurityException(SecurityRunnable runnable) {
        try {
            runnable.run();
            System.assert(false, 'Expected SecurityGate to throw.');
        } catch (SecurityGate.SecurityException expected) {
            System.assert(String.isNotBlank(expected.getMessage()));
        }
    }
}

