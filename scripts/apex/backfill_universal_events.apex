List<Incident__c> incidents = [
    SELECT Id, Severity__c, Status__c, Description__c, Users_Affected__c,
           Revenue_at_Risk__c, Self_Heal_Attempted__c, Tenant__c,
           Integration_Log__c, Integration_Endpoint__c
    FROM Incident__c
    WHERE Status__c NOT IN ('Resolved', 'Closed')
    ORDER BY CreatedDate DESC
    LIMIT 200
];
UniversalEventNormalizer.normalizeIncidents(incidents);

List<Integration_Log__c> logs = [
    SELECT Id, API_Name__c, Status__c, Error_Message__c, Response_Time__c,
           Tenant__c, Integration_Endpoint__c
    FROM Integration_Log__c
    ORDER BY CreatedDate DESC
    LIMIT 200
];
UniversalEventNormalizer.normalizeIntegrationLogs(logs);

System.debug('Backfilled Universal Events from ' + incidents.size() + ' incidents and ' + logs.size() + ' integration logs.');
