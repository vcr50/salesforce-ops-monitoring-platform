trigger IncidentTrigger on Incident__c (before insert, before update) {
    SEOMPAutomationService.applyIncidentResolutionState(Trigger.new, Trigger.oldMap);
}
