// scripts/apex/generateTestData.apex
System.debug('Starting Test Data Generation for SentinelFlow...');

// 0. Create Environment
Environment__c prodEnv = new Environment__c(Name = 'Production');
Environment__c stageEnv = new Environment__c(Name = 'Staging');
insert new List<Environment__c>{prodEnv, stageEnv};

// 1. Create SLA Policies
List<SLA_Policy__c> policies = new List<SLA_Policy__c>();
policies.add(new SLA_Policy__c(Name = 'Tier 1 API Gateway', Severity__c = 'Critical', Response_Time_Min__c = 5, Resolution_Time_Min__c = 15));
policies.add(new SLA_Policy__c(Name = 'ERP Data Sync', Severity__c = 'High', Response_Time_Min__c = 15, Resolution_Time_Min__c = 60));
policies.add(new SLA_Policy__c(Name = 'Payment Service', Severity__c = 'Medium', Response_Time_Min__c = 30, Resolution_Time_Min__c = 120));
insert policies;

// 2. Create Integration Logs
List<Integration_Log__c> logs = new List<Integration_Log__c>();
logs.add(new Integration_Log__c(
    API_Name__c = 'Payment Gateway Auth',
    Status__c = 'Failed',
    Response_Time__c = 5200,
    Error_Message__c = 'Connection pool exhausted - unable to obtain database connection within 5 seconds.'
));

logs.add(new Integration_Log__c(
    API_Name__c = 'Salesforce Core Sync',
    Status__c = 'Timeout',
    Response_Time__c = 8000,
    Error_Message__c = 'Apex CPU limit breached - recursive trigger detected on Order update.'
));

logs.add(new Integration_Log__c(
    API_Name__c = 'ERP Batch Push',
    Status__c = 'Failed',
    Response_Time__c = 1500,
    Error_Message__c = 'Payload schema mismatch: Missing required field "External_Id__c".'
));

logs.add(new Integration_Log__c(
    API_Name__c = 'SMTP Gateway',
    Status__c = 'Warning',
    Response_Time__c = 1200,
    Error_Message__c = 'Elevated response time detected during peak send window.'
));
insert logs;

// 3. Create Incidents linked to Logs
List<Incident__c> incidents = new List<Incident__c>();
incidents.add(new Incident__c(
    Description__c = 'CRITICAL: Payment Gateway Auth Failed',
    Severity__c = 'Critical',
    Status__c = 'Open',
    Integration_Log__c = logs[0].Id,
    Environment__c = prodEnv.Id,
    SLA_Policy__c = policies[2].Id
));

incidents.add(new Incident__c(
    Description__c = 'Salesforce Core Sync CPU Limit Breach',
    Severity__c = 'Critical',
    Status__c = 'Open',
    Integration_Log__c = logs[1].Id,
    Environment__c = prodEnv.Id
));

incidents.add(new Incident__c(
    Description__c = 'ERP Batch Push Schema Error',
    Severity__c = 'High',
    Status__c = 'Open',
    Integration_Log__c = logs[2].Id,
    Environment__c = stageEnv.Id,
    SLA_Policy__c = policies[1].Id
));

incidents.add(new Incident__c(
    Description__c = 'SMTP Gateway Latency',
    Severity__c = 'Medium',
    Status__c = 'Open',
    Integration_Log__c = logs[3].Id,
    Environment__c = prodEnv.Id
));
insert incidents;

System.debug('Data generation complete. Generated ' + incidents.size() + ' incidents.');
