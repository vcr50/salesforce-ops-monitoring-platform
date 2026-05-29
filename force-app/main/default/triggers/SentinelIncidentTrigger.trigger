trigger SentinelIncidentTrigger on Sentinel_Incident__c (after insert, after update) {
    List<Id> pendingApprovalIncidentIds = new List<Id>();

    for (Sentinel_Incident__c incident : Trigger.new) {
        Boolean isPendingApproval = incident.Approval_Status__c == 'Pending Approval';
        Boolean transitionedToPendingApproval = Trigger.isInsert
            ? isPendingApproval
            : isPendingApproval && Trigger.oldMap.get(incident.Id).Approval_Status__c != 'Pending Approval';

        if (transitionedToPendingApproval) {
            pendingApprovalIncidentIds.add(incident.Id);
        }
    }

    if (!pendingApprovalIncidentIds.isEmpty()
        && (!Test.isRunningTest() || SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests)) {
        SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(pendingApprovalIncidentIds);
    }
}
