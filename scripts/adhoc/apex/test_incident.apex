// 1. Create a core endpoint
Integration_Endpoint__c endpoint = new Integration_Endpoint__c(
    Name = 'Shopify Checkout API',
    Endpoint_URL__c = 'https://api.shopify.com/checkout',
    Auth_Type__c = 'OAuth 2.0',
    Retry_Policy__c = 'Exponential Backoff',
    Max_Retries__c = 3
);
insert endpoint;

// 2. Simulate a critical failure log
Integration_Log__c log = new Integration_Log__c(
    API_Name__c = 'Shopify Checkout API',
    Status__c = 'Failed',
    Response_Time__c = 8500,
    Error_Message__c = 'OAuth Token Expired - 401 Unauthorized',
    Integration_Endpoint__c = endpoint.Id
);
insert log;

// 3. Create Incident Directly
Incident__c inc = new Incident__c(
    Integration_Log__c = log.Id,
    Integration_Endpoint__c = endpoint.Id,
    Status__c = 'New',
    Description__c = 'Integration failed automatically detected',
    Error_Type__c = 'Authentication Error',
    Users_Affected__c = 1500
);
insert inc;

// 4. Force calculate the revenue risk (assume ARPU is default 42.50, and our regex finds 1500 users from payload)
BusinessImpactCalculator.calculateAllOpen();

// 5. Run Pulse Sync to generate Revenue Risk Ledger
RevenuePulseService.executePulseSync();

// 6. Test Zentom Agentforce Payload
ZentomGetIncidentDetailsAction.IncidentDetailRequest req = new ZentomGetIncidentDetailsAction.IncidentDetailRequest();
req.incidentId = inc.Id;
List<ZentomGetIncidentDetailsAction.IncidentDetailResult> aiPayload = ZentomGetIncidentDetailsAction.getIncidentDetails(new List<ZentomGetIncidentDetailsAction.IncidentDetailRequest>{req});

// 7. Output Results
Incident__c finalInc = [SELECT Name, Revenue_at_Risk__c FROM Incident__c WHERE Id = :inc.Id];
System.debug('\n\n=== INCIDENT SIMULATION ===');
System.debug('Incident: ' + finalInc.Name);
System.debug('Calculated Revenue at Risk: $' + finalInc.Revenue_at_Risk__c);
System.debug('AI Guardian Context Payload:\n' + aiPayload[0].technicalLog);
System.debug('===========================\n\n');
