// simulate_incident.apex
Id logId = 'a0BdL000017whCvUAI';

// Reset the incident so it can be picked up
Incident__c inc = [SELECT Id, Self_Heal_Attempted__c, Status__c, Description__c FROM Incident__c WHERE Integration_Log__c = :logId LIMIT 1];
inc.Self_Heal_Attempted__c = false;
inc.Status__c = 'Open';
update inc;

// Trigger the Zentom Orchestration Engine
System.debug('Triggering Self Healing Engine for Log ID: ' + logId);
SelfHealingEngine.processFailedLogs(new List<Id>{logId});

// Verify Results
Incident__c result = [SELECT Id, Status__c, Root_Cause__c, Recommended_Action__c, AI_Confidence__c, Auto_Heal_Status__c FROM Incident__c WHERE Id = :inc.Id];
System.debug('--- ZENTOM ORCHESTRATION RESULT ---');
System.debug('Status: ' + result.Status__c);
System.debug('Confidence: ' + result.AI_Confidence__c);
System.debug('Recommended Action: ' + result.Recommended_Action__c);
System.debug('Root Cause / Rationale: ' + result.Root_Cause__c);
System.debug('Auto Heal Status: ' + result.Auto_Heal_Status__c);
