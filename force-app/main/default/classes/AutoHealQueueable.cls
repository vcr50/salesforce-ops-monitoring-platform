/**
 * AutoHealQueueable
 * Chained from AIAnalysisQueueable when AI confidence >= 90%.
 * Executes the recommended healing action asynchronously.
 * Bulkified.
 *
 * @author  Tomcodex
 * @version 2.0
 */
public with sharing class AutoHealQueueable implements Queueable {

    private List<Id> incidentIds;

    public AutoHealQueueable(Id incidentId) {
        this.incidentIds = new List<Id>{ incidentId };
    }

    public AutoHealQueueable(List<Id> incidentIds) {
        this.incidentIds = incidentIds;
    }

    public void execute(QueueableContext ctx) {
        if (incidentIds == null || incidentIds.isEmpty()) {
            return;
        }

        List<Incident__c> incidentsToUpdate = new List<Incident__c>();

        for (Id incidentId : incidentIds) {
            try {
                SelfHealingEngine.HealResult result = SelfHealingEngine.healIncident(incidentId);

                AuditTrailService.log(
                    incidentId,
                    'Incident__c',
                    'Async Auto-Heal Executed',
                    null,
                    'Action: ' + result.actionTaken + ' | Result: ' + result.message
                    + ' | Success: ' + result.success
                );

            } catch (Exception ex) {
                AuditTrailService.log(
                    incidentId,
                    'Incident__c',
                    'Async Auto-Heal Failed',
                    null,
                    'Error: ' + ex.getMessage() + ' — escalating to on-call team.'
                );

                incidentsToUpdate.add(new Incident__c(Id = incidentId, Status__c = 'Investigating'));
            }
        }

        if (!incidentsToUpdate.isEmpty()) {
            try {
                update as user incidentsToUpdate;
            } catch (Exception updateEx) {
                // Non-fatal
            }
        }
    }
}
