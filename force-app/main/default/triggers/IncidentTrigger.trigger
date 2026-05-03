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
trigger IncidentTrigger on Incident__c (after insert, before update) {

    if (Trigger.isInsert && Trigger.isAfter) {
        List<Incident__c> criticalIncidents = new List<Incident__c>();

        for (Incident__c inc : Trigger.new) {
            // Initialize Auto_Heal_Status on new records
            if (inc.Auto_Heal_Status__c == null) {
                // Use a separate update list — can't DML in after insert without Queueable
                // This is handled in SEOMPAutomationService.createIncidentsForFailedLogs
                // which sets Auto_Heal_Status__c at insert time
            }
            if (inc.Severity__c == 'Critical') {
                criticalIncidents.add(inc);
            }
        }

        // Send email and Slack alerts for Critical incidents
        for (Incident__c inc : criticalIncidents) {
            NotificationService.sendIncidentAlert(inc.Id);
            NotificationService.sendSlackAlert(inc.Id);
        }
    }

    if (Trigger.isUpdate && Trigger.isBefore) {
        // Apply resolved_time stamp when status moves to Resolved/Closed
        SEOMPAutomationService.applyIncidentResolutionState(Trigger.new, Trigger.oldMap);
    }
}
