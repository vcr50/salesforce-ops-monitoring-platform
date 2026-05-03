Set<String> environmentNames = new Set<String>{
    'Production',
    'QA Sandbox',
    'Developer Org'
};

Map<String, Environment__c> environmentsByName = new Map<String, Environment__c>();
for (Environment__c environmentRecord : [
    SELECT Id, Name
    FROM Environment__c
    WHERE Name IN :environmentNames
]) {
    environmentsByName.put(environmentRecord.Name, environmentRecord);
}

List<Environment__c> environmentsToInsert = new List<Environment__c>();
if (!environmentsByName.containsKey('Production')) {
    environmentsToInsert.add(new Environment__c(
        Name = 'Production',
        Org_Id__c = '00DSentinelFlowDEMO00001'
    ));
}
if (!environmentsByName.containsKey('QA Sandbox')) {
    environmentsToInsert.add(new Environment__c(
        Name = 'QA Sandbox',
        Org_Id__c = '00DSentinelFlowDEMO00002'
    ));
}
if (!environmentsByName.containsKey('Developer Org')) {
    environmentsToInsert.add(new Environment__c(
        Name = 'Developer Org',
        Org_Id__c = '00DSentinelFlowDEMO00003'
    ));
}

if (!environmentsToInsert.isEmpty()) {
    insert environmentsToInsert;
    for (Environment__c environmentRecord : environmentsToInsert) {
        environmentsByName.put(environmentRecord.Name, environmentRecord);
    }
}

Map<String, SLA_Policy__c> policiesBySeverity = new Map<String, SLA_Policy__c>();
for (SLA_Policy__c policyRecord : [
    SELECT Id, Severity__c
    FROM SLA_Policy__c
    WHERE Severity__c IN ('Critical', 'High', 'Medium')
]) {
    if (!policiesBySeverity.containsKey(policyRecord.Severity__c)) {
        policiesBySeverity.put(policyRecord.Severity__c, policyRecord);
    }
}

List<SLA_Policy__c> policiesToInsert = new List<SLA_Policy__c>();
if (!policiesBySeverity.containsKey('Critical')) {
    policiesToInsert.add(new SLA_Policy__c(
        Name = 'Critical Demo Policy',
        Severity__c = 'Critical',
        Response_Time_Min__c = 15,
        Resolution_Time_Min__c = 120
    ));
}
if (!policiesBySeverity.containsKey('High')) {
    policiesToInsert.add(new SLA_Policy__c(
        Name = 'High Demo Policy',
        Severity__c = 'High',
        Response_Time_Min__c = 30,
        Resolution_Time_Min__c = 240
    ));
}
if (!policiesBySeverity.containsKey('Medium')) {
    policiesToInsert.add(new SLA_Policy__c(
        Name = 'Medium Demo Policy',
        Severity__c = 'Medium',
        Response_Time_Min__c = 60,
        Resolution_Time_Min__c = 480
    ));
}

if (!policiesToInsert.isEmpty()) {
    insert policiesToInsert;
    for (SLA_Policy__c policyRecord : policiesToInsert) {
        policiesBySeverity.put(policyRecord.Severity__c, policyRecord);
    }
}

Set<String> demoApiNames = new Set<String>{
    'Orders API',
    'Billing API',
    'Inventory API',
    'Shipping API'
};

Map<String, Integration_Log__c> logsByApiName = new Map<String, Integration_Log__c>();
for (Integration_Log__c logRecord : [
    SELECT Id, API_Name__c, Status__c
    FROM Integration_Log__c
    WHERE API_Name__c IN :demoApiNames
]) {
    logsByApiName.put(logRecord.API_Name__c, logRecord);
}

List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
if (!logsByApiName.containsKey('Orders API')) {
    logsToInsert.add(new Integration_Log__c(
        API_Name__c = 'Orders API',
        Status__c = 'Failed',
        Response_Time__c = 2400,
        Error_Message__c = 'Gateway timeout while posting order confirmation.'
    ));
}
if (!logsByApiName.containsKey('Billing API')) {
    logsToInsert.add(new Integration_Log__c(
        API_Name__c = 'Billing API',
        Status__c = 'Failed',
        Response_Time__c = 1350,
        Error_Message__c = 'Authentication token expired.'
    ));
}
if (!logsByApiName.containsKey('Inventory API')) {
    logsToInsert.add(new Integration_Log__c(
        API_Name__c = 'Inventory API',
        Status__c = 'Warning',
        Response_Time__c = 950,
        Error_Message__c = 'Inventory sync completed with delayed response.'
    ));
}
if (!logsByApiName.containsKey('Shipping API')) {
    logsToInsert.add(new Integration_Log__c(
        API_Name__c = 'Shipping API',
        Status__c = 'Success',
        Response_Time__c = 420
    ));
}

if (!logsToInsert.isEmpty()) {
    insert logsToInsert;
}

Id productionEnvironmentId = environmentsByName.containsKey('Production')
    ? environmentsByName.get('Production').Id
    : null;

Boolean hasManualIncident = false;
for (Incident__c incidentRecord : [
    SELECT Id, Description__c
    FROM Incident__c
    WHERE Environment__c = :productionEnvironmentId
]) {
    if (incidentRecord.Description__c == 'Manual escalation for payment reconciliation lag.') {
        hasManualIncident = true;
        break;
    }
}

if (!hasManualIncident) {
    insert new Incident__c(
        Severity__c = 'Critical',
        Status__c = 'Escalated',
        Description__c = 'Manual escalation for payment reconciliation lag.',
        Environment__c = productionEnvironmentId,
        SLA_Policy__c = policiesBySeverity.get('Critical').Id
    );
}

System.debug('SentinelFlow dashboard sample data ensured successfully.');
