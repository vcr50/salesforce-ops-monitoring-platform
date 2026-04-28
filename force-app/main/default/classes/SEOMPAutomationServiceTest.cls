@IsTest
private class SEOMPAutomationServiceTest {
    @TestSetup
    static void createReferenceData() {
        insert new Environment__c(
            Name = 'Developer Org',
            Org_Id__c = '00DSEOMPTST000001'
        );

        insert new List<SLA_Policy__c>{
            new SLA_Policy__c(
                Name = 'Critical Test Policy',
                Severity__c = 'Critical',
                Response_Time_Min__c = 15,
                Resolution_Time_Min__c = 120
            ),
            new SLA_Policy__c(
                Name = 'High Test Policy',
                Severity__c = 'High',
                Response_Time_Min__c = 30,
                Resolution_Time_Min__c = 240
            )
        };
    }

    @IsTest
    static void incidentResolutionTimestampIsManaged() {
        Incident__c incidentRecord = new Incident__c(
            Severity__c = 'High',
            Status__c = 'New',
            Description__c = 'Test incident'
        );
        insert incidentRecord;

        incidentRecord.Status__c = 'Resolved';
        update incidentRecord;

        Incident__c resolvedIncident = [
            SELECT Status__c, Resolved_Time__c
            FROM Incident__c
            WHERE Id = :incidentRecord.Id
        ];

        System.assertEquals('Resolved', resolvedIncident.Status__c);
        System.assertNotEquals(null, resolvedIncident.Resolved_Time__c);

        resolvedIncident.Status__c = 'In Progress';
        update resolvedIncident;

        Incident__c reopenedIncident = [
            SELECT Status__c, Resolved_Time__c
            FROM Incident__c
            WHERE Id = :incidentRecord.Id
        ];

        System.assertEquals('In Progress', reopenedIncident.Status__c);
        System.assertEquals(null, reopenedIncident.Resolved_Time__c);
    }

    @IsTest
    static void failedIntegrationLogCreatesIncident() {
        Test.startTest();
        Integration_Log__c logRecord = new Integration_Log__c(
            API_Name__c = 'Orders API',
            Status__c = 'Failed',
            Response_Time__c = 1800,
            Error_Message__c = 'Timeout'
        );
        insert logRecord;
        Test.stopTest();

        List<Incident__c> incidents = [
            SELECT Severity__c, Status__c, Integration_Log__c, Description__c
            FROM Incident__c
            WHERE Integration_Log__c = :logRecord.Id
        ];

        System.assertEquals(1, incidents.size());
        System.assertEquals('Critical', incidents[0].Severity__c);
        System.assertEquals('New', incidents[0].Status__c);
        System.assert(incidents[0].Description__c.contains('Orders API'));
    }

    @IsTest
    static void repeatedFailedStatusDoesNotCreateDuplicateOpenIncident() {
        Integration_Log__c logRecord = new Integration_Log__c(
            API_Name__c = 'Billing API',
            Status__c = 'Success',
            Response_Time__c = 400
        );
        insert logRecord;

        Test.startTest();
        logRecord.Status__c = 'Failed';
        logRecord.Error_Message__c = 'Initial failure';
        update logRecord;

        logRecord.Error_Message__c = 'Still failing';
        update logRecord;
        Test.stopTest();

        Integer incidentCount = [
            SELECT COUNT()
            FROM Incident__c
            WHERE Integration_Log__c = :logRecord.Id
        ];

        System.assertEquals(1, incidentCount);
    }

    @IsTest
    static void recoveredIntegrationLogClosesOpenIncident() {
        Integration_Log__c logRecord = new Integration_Log__c(
            API_Name__c = 'Warehouse API',
            Status__c = 'Failed',
            Response_Time__c = 900,
            Error_Message__c = 'Service unavailable'
        );
        insert logRecord;

        Incident__c incidentRecord = [
            SELECT Id, Status__c
            FROM Incident__c
            WHERE Integration_Log__c = :logRecord.Id
            LIMIT 1
        ];

        incidentRecord.Status__c = 'In Progress';
        update incidentRecord;

        Test.startTest();
        logRecord.Status__c = 'Success';
        logRecord.Error_Message__c = null;
        update logRecord;
        Test.stopTest();

        Incident__c closedIncident = [
            SELECT Status__c, Resolved_Time__c
            FROM Incident__c
            WHERE Id = :incidentRecord.Id
        ];

        System.assertEquals('Closed', closedIncident.Status__c);
        System.assertNotEquals(null, closedIncident.Resolved_Time__c);
    }
}
