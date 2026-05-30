trigger SentinelIncidentTrigger on Sentinel_Incident__c (after insert, after update) {
    List<Id> pendingApprovalIncidentIds = new List<Id>();

    // Streaming telemetry — incident buckets
    List<Sentinel_Incident__c> createdIncidents = new List<Sentinel_Incident__c>();
    List<Sentinel_Incident__c> approvalRequiredIncidents = new List<Sentinel_Incident__c>();
    List<Sentinel_Incident__c> riskUpdatedIncidents = new List<Sentinel_Incident__c>();

    for (Sentinel_Incident__c incident : Trigger.new) {
        Boolean isPendingApproval = incident.Approval_Status__c == 'Pending Approval';
        Boolean transitionedToPendingApproval = Trigger.isInsert
            ? isPendingApproval
            : isPendingApproval && Trigger.oldMap.get(incident.Id).Approval_Status__c != 'Pending Approval';

        if (transitionedToPendingApproval) {
            pendingApprovalIncidentIds.add(incident.Id);
        }

        // Streaming telemetry — categorise records for event publishing
        if (Trigger.isInsert) {
            createdIncidents.add(incident);
            if (isPendingApproval) {
                approvalRequiredIncidents.add(incident);
            }
        } else {
            if (incident.Risk_Level__c != Trigger.oldMap.get(incident.Id).Risk_Level__c) {
                riskUpdatedIncidents.add(incident);
            }
            if (transitionedToPendingApproval) {
                approvalRequiredIncidents.add(incident);
            }
        }
    }

    if (!pendingApprovalIncidentIds.isEmpty()
        && (!Test.isRunningTest() || SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests)) {
        SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(pendingApprovalIncidentIds);
    }

    // Milestone 59B: Propagate approval status changes back to Sentinel_Prediction__c
    Map<Id, String> predictionIdToDecision = new Map<Id, String>();
    if (Trigger.isUpdate) {
        for (Sentinel_Incident__c incident : Trigger.new) {
            Sentinel_Incident__c oldInc = Trigger.oldMap.get(incident.Id);
            if (incident.Source_Prediction__c != null && incident.Approval_Status__c != oldInc.Approval_Status__c) {
                if (incident.Approval_Status__c == 'Approved') {
                    predictionIdToDecision.put(incident.Source_Prediction__c, 'Confirmed');
                } else if (incident.Approval_Status__c == 'Rejected') {
                    predictionIdToDecision.put(incident.Source_Prediction__c, 'Dismissed');
                }
            }
        }
    }

    if (!predictionIdToDecision.isEmpty()) {
        for (Id predId : predictionIdToDecision.keySet()) {
            SentinelPredictionGovernanceService.updatePredictionDecision(predId, predictionIdToDecision.get(predId));
        }
    }

    // Streaming telemetry — publish dashboard platform events (bulk, deduplication-safe)
    if (!createdIncidents.isEmpty()) {
        SentinelFlowEventPublisher.publishBulk(
            'INCIDENT_CREATED', createdIncidents,
            'SentinelIncidentTrigger', 'New incident created in SentinelFlow.'
        );
    }
    if (!riskUpdatedIncidents.isEmpty()) {
        SentinelFlowEventPublisher.publishBulk(
            'RISK_UPDATED', riskUpdatedIncidents,
            'SentinelIncidentTrigger', 'Incident risk level updated.'
        );
    }
    if (!approvalRequiredIncidents.isEmpty()) {
        SentinelFlowEventPublisher.publishBulk(
            'APPROVAL_REQUIRED', approvalRequiredIncidents,
            'SentinelIncidentTrigger', 'Incident requires Guardian Gate approval.'
        );
    }
}
