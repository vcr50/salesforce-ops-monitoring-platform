/**
 * OperationalMemoryEngine
 * Phase 4 of the CTO Blueprint: The Operational Memory System.
 * 
 * Turns incidents into reusable intelligence. When an incident is fully resolved,
 * this engine aggregates all related data (telemetry, AI decisions, execution outcomes, 
 * revenue impact) into an immutable JSON artifact stored in the audit trail.
 * This becomes the long-term training dataset (the moat) for future predictive AI.
 *
 * @author SentinelFlow
 * @version 1.0
 */
public inherited sharing class OperationalMemoryEngine {

    /**
     * Called when an Incident is moved to 'Resolved' or 'Closed' status.
     * Aggregates the full incident lifecycle into a Memory Record.
     */
    public static void archiveIncidentToMemory(List<Id> closedIncidentIds) {
        if (closedIncidentIds == null || closedIncidentIds.isEmpty()) return;

        // Query the incident and all related intelligence graphs
        List<Incident__c> incidents = [
            SELECT Id, Name, Severity__c, Status__c, Revenue_at_Risk__c, Users_Affected__c,
                   Root_Cause__c, Recommended_Action__c, AI_Confidence__c,
                   Integration_Endpoint__c, CreatedDate, LastModifiedDate,
                   (SELECT Id, Confidence_Score__c, Recommended_Action__c, Auto_Executed__c, Matched_Rule__c FROM AI_Decisions__r ORDER BY CreatedDate DESC),
                   (SELECT Id, Action_Taken__c, Result__c, Retry_Attempt__c FROM Auto_Heal_Runs__r ORDER BY CreatedDate ASC)
            FROM Incident__c
            WHERE Id IN :closedIncidentIds
        ];

        List<Audit_Trail__c> memoryEntries = new List<Audit_Trail__c>();

        for (Incident__c inc : incidents) {
            Map<String, Object> memoryObj = new Map<String, Object>();
            memoryObj.put('incidentId', inc.Id);
            memoryObj.put('incidentName', inc.Name);
            memoryObj.put('severity', inc.Severity__c);
            
            // Blast Radius & Revenue Impact
            memoryObj.put('blastRadius', new Map<String, Object>{
                'usersAffected' => inc.Users_Affected__c,
                'revenueImpact' => inc.Revenue_at_Risk__c,
                'integrationId' => inc.Integration_Endpoint__c
            });
            
            // Intelligence Data
            memoryObj.put('rootCause', inc.Root_Cause__c);
            memoryObj.put('finalStatus', inc.Status__c);
            memoryObj.put('timeToResolutionMs', inc.LastModifiedDate.getTime() - inc.CreatedDate.getTime());
            
            // AI Decisions
            List<Map<String, Object>> aiDecisions = new List<Map<String, Object>>();
            Boolean governedByPolicy = false;
            for (AI_Decision__c aid : inc.AI_Decisions__r) {
                aiDecisions.add(new Map<String, Object>{
                    'confidence' => aid.Confidence_Score__c,
                    'action' => aid.Recommended_Action__c,
                    'autoExecuted' => aid.Auto_Executed__c,
                    'policyRule' => aid.Matched_Rule__c
                });
                if (!aid.Auto_Executed__c && aid.Confidence_Score__c != null) {
                    governedByPolicy = true; // Indicates human oversight was mandated
                }
            }
            memoryObj.put('aiDecisions', aiDecisions);
            
            // Recovery Operations
            List<Map<String, Object>> recoveryPath = new List<Map<String, Object>>();
            Boolean recoverySuccess = false;
            for (Auto_Heal_Run__c ahr : inc.Auto_Heal_Runs__r) {
                recoveryPath.add(new Map<String, Object>{
                    'action' => ahr.Action_Taken__c,
                    'result' => ahr.Result__c,
                    'attempt' => ahr.Retry_Attempt__c
                });
                if (ahr.Result__c == 'Succeeded') {
                    recoverySuccess = true;
                }
            }
            memoryObj.put('recoveryPath', recoveryPath);
            memoryObj.put('recoverySuccess', recoverySuccess);
            memoryObj.put('humanOverrideMandated', governedByPolicy);

            String memoryPayload = JSON.serializePretty(memoryObj);

            Audit_Trail__c trail = new Audit_Trail__c();
            trail.Object_Name__c = 'Operational_Memory';
            trail.Action__c = 'Archive Resolution Path';
            trail.Old_Value__c = 'Incident Closed';
            trail.New_Value__c = memoryPayload;
            trail.Record_Id__c = inc.Id;
            trail.Timestamp__c = System.now();
            
            memoryEntries.add(trail);
        }

        if (!memoryEntries.isEmpty()) {
            AuditTrailService.logAll(memoryEntries);
        }
    }
}

