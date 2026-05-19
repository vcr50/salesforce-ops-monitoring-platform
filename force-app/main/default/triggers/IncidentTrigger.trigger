/**
 * IncidentTrigger
 * Fires after insert/update on Incident__c.
 *
 *  after insert  — Initialize Auto_Heal_Status, resolve SLA policy, send Critical alerts
 *  after update  — Apply resolved_time when status changes to Resolved/Closed
 *
 * @author  Tomcodex
 * @version 2.0
 */
trigger IncidentTrigger on Incident__c (after insert, before update, after update) {

    if (Trigger.isInsert && Trigger.isAfter) {
        List<Incident__c> criticalIncidents = new List<Incident__c>();

        List<Id> incidentIdsForAnalysis = new List<Id>();

        for (Incident__c inc : Trigger.new) {
            // Initialize Auto_Heal_Status on new records
            if (inc.Auto_Heal_Status__c == null) {
                // Handled in SentinelFlowAutomationService
            }
            if (inc.Severity__c == 'Critical') {
                criticalIncidents.add(inc);
            }
            
            // Queue for Autonomous AI Analysis and Auto-Heal (Phase 5)
            incidentIdsForAnalysis.add(inc.Id);
        }

        // Trigger AI Analysis Queueable asynchronously
        if (!incidentIdsForAnalysis.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new AIAnalysisQueueable(incidentIdsForAnalysis));
        }

        // Send email and Slack alerts for Critical incidents
        for (Incident__c inc : criticalIncidents) {
            NotificationService.sendIncidentAlert(inc.Id);
            NotificationService.sendSlackAlert(inc.Id);
        }

        // Normalize incidents into the CTO universal event layer
        UniversalEventNormalizer.normalizeIncidents(Trigger.new);
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        // Apply resolved_time stamp when status moves to Resolved/Closed
        SentinelFlowAutomationService.applyIncidentResolutionState(Trigger.new, Trigger.oldMap);

        // Keep the universal event current as incidents move through governance/healing
        UniversalEventNormalizer.normalizeIncidents(Trigger.new);
    }
    
    if (Trigger.isUpdate && Trigger.isAfter) {
        List<Id> closedIncidentIds = new List<Id>();
        for (Incident__c inc : Trigger.new) {
            Incident__c oldInc = Trigger.oldMap.get(inc.Id);
            // If the status just transitioned to Resolved or Closed
            if ((inc.Status__c == 'Resolved' || inc.Status__c == 'Closed') && 
                (oldInc.Status__c != 'Resolved' && oldInc.Status__c != 'Closed')) {
                closedIncidentIds.add(inc.Id);
            }
        }
        
        if (!closedIncidentIds.isEmpty()) {
            // Future method / Queueable would be better here for large DML on resolution, 
            // but for Phase 4 MVP, synchronous aggregation into Audit Trail is sufficient.
            OperationalMemoryEngine.archiveIncidentToMemory(closedIncidentIds);
        }
    }
}
