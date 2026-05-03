// 1. Setup Tenant and Settings
SentinelFlow_Settings__c settings = SentinelFlow_Settings__c.getOrgDefaults();
settings.Endpoint_Active__c = true;
settings.Enable_Alerts__c = true;
settings.Max_Retry__c = 3;
upsert settings;

Tenant__c tenant;
List<Tenant__c> existingTenants = [SELECT Id, Name, API_Key__c FROM Tenant__c WHERE API_Key__c = 'E2E-TEST-KEY-123' LIMIT 1];
if (existingTenants.isEmpty()) {
    tenant = new Tenant__c(
        Name = 'Acme Corp',
        API_Key__c = 'E2E-TEST-KEY-123',
        Slack_Webhook_Path__c = '/services/T000000/B000000/TESTWEBHOOK' // Dummy path
    );
    insert tenant;
    System.debug('✅ Created new Tenant: ' + tenant.Name);
} else {
    tenant = existingTenants[0];
    System.debug('✅ Found existing Tenant: ' + tenant.Name);
}

// 3. Simulate External Ingestion via REST API
RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
req.requestURI = '/services/apexrest/sentinelflow/incidents';
req.httpMethod = 'POST';
req.requestBody = Blob.valueOf('[{ "error": "Critical: Main Database Connection Pool Exhausted.", "system": "New Relic", "apiKey": "E2E-TEST-KEY-123", "severity": "Critical" }]');

RestContext.request = req;
RestContext.response = res;

System.debug('📡 Simulating incoming webhook payload from monitoring tool...');
IncidentRestApi.doPost();
System.debug('✅ REST API Response: ' + res.responseBody.toString());

// 4. Wait for async processing (since we can't pause execution in Apex script, 
// we'll query immediately. Some @future things like Slack might take a second, 
// but BusinessImpactCalculator is synchronous via trigger in some implementations.
// Let's verify what was created.
List<Incident__c> createdIncidents = [
    SELECT Id, Name, Severity__c, Status__c, Auto_Heal_Status__c, Revenue_at_Risk__c, Users_Affected__c, Retry_Count__c, Max_Retry__c 
    FROM Incident__c 
    WHERE Tenant__c = :tenant.Id 
    ORDER BY CreatedDate DESC 
    LIMIT 1
];

if (createdIncidents.size() > 0) {
    Incident__c inc = createdIncidents[0];
    System.debug('✅ Incident Created: ' + inc.Name);
    System.debug('   - Severity assigned: ' + inc.Severity__c);
    System.debug('   - Status: ' + inc.Status__c);
    System.debug('   - Auto Heal Status: ' + inc.Auto_Heal_Status__c);
    System.debug('   - Retry Count: ' + inc.Retry_Count__c + ' / ' + inc.Max_Retry__c);
    System.debug('   - Users Affected Calculated: ' + inc.Users_Affected__c);
    System.debug('   - Revenue Risk Calculated: $' + inc.Revenue_at_Risk__c);
    

} else {
    System.debug('❌ Failed to create Incident.');
}

System.debug('--- END OF TEST ---');
