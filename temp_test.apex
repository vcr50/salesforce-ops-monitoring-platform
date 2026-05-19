try {
    Id incId = [SELECT Id FROM Incident__c WHERE Status__c != 'Resolved' LIMIT 1].Id;
    System.debug(SelfHealingEngine.healIncident(incId));
} catch(Exception e) {
    System.debug('ERROR: ' + e.getMessage() + ' - ' + e.getStackTraceString());
}
