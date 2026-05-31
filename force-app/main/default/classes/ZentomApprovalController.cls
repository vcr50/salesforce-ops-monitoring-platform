public with sharing class ZentomApprovalController {
    @AuraEnabled(cacheable=true)
    public static ApprovalContext getIncident(Id incidentId) {
        return toContext(loadIncident(incidentId));
    }

    @AuraEnabled
    public static ApprovalContext approveIncident(Id incidentId) {
        Sentinel_Incident__c incident = loadIncident(incidentId);
        incident.Status__c = 'Approved';
        incident.Approval_Status__c = 'Approved';
        incident.Recommendation_Status__c = 'Approved';
        incident.Approved_By__c = UserInfo.getUserId();
        incident.Approved_At__c = System.now();
        incident.Rejection_Reason__c = null;
        incident.Execution_Status__c = 'Ready for Execution';
        incident.Next_Action__c = 'Approval captured. Ready to create Salesforce Case.';
        update incident;

        createAuditLog(incident.Id, 'HUMAN_APPROVED', 'APPROVED', null);
        return toContext(loadIncident(incident.Id));
    }

    @AuraEnabled
    public static ApprovalContext rejectIncident(Id incidentId, String reason) {
        Sentinel_Incident__c incident = loadIncident(incidentId);
        incident.Status__c = 'Closed';
        incident.Approval_Status__c = 'Rejected';
        incident.Recommendation_Status__c = 'Rejected';
        incident.Rejection_Reason__c = String.isBlank(reason) ? 'No reason provided.' : reason;
        incident.Next_Action__c = 'Recommendation rejected. No external execution will run.';
        update incident;

        createAuditLog(incident.Id, 'HUMAN_REJECTED', 'REJECTED', incident.Rejection_Reason__c);
        return toContext(loadIncident(incident.Id));
    }

    private static Sentinel_Incident__c loadIncident(Id incidentId) {
        if (incidentId == null) {
            throw new AuraHandledException('Incident id is required.');
        }

        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Status__c, Risk_Level__c, Risk_Score__c, Policy_Decision__c,
                Recommended_Action__c, Recommendation_Status__c, Approval_Status__c,
                Approved_By__c, Approved_At__c, Rejection_Reason__c, Next_Action__c,
                Execution_Status__c, Execution_Action__c, Executed_At__c,
                Execution_Result__c, Created_Case__c
            FROM Sentinel_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        if (incidents.isEmpty()) {
            throw new AuraHandledException('Incident was not found.');
        }

        return incidents[0];
    }

    private static void createAuditLog(
        Id incidentId,
        String eventType,
        String decision,
        String reason
    ) {
        insert new Sentinel_Audit_Log__c(
            Incident__c = incidentId,
            Event_Type__c = eventType,
            Decision__c = decision,
            Request_Payload__c = reason,
            Created_By_System__c = true,
            Trace_Id__c = String.valueOf(incidentId)
        );
    }

    private static ApprovalContext toContext(Sentinel_Incident__c incident) {
        ApprovalContext context = new ApprovalContext();
        context.incidentId = incident.Id;
        context.name = incident.Name;
        context.status = incident.Status__c;
        context.riskLevel = incident.Risk_Level__c;
        context.riskScore = incident.Risk_Score__c;
        context.policyDecision = incident.Policy_Decision__c;
        context.recommendedAction = incident.Recommended_Action__c;
        context.recommendationStatus = incident.Recommendation_Status__c;
        context.approvalStatus = incident.Approval_Status__c;
        context.approvedById = incident.Approved_By__c;
        context.approvedAt = incident.Approved_At__c;
        context.rejectionReason = incident.Rejection_Reason__c;
        context.nextAction = incident.Next_Action__c;
        context.executionStatus = incident.Execution_Status__c;
        context.executionAction = incident.Execution_Action__c;
        context.executedAt = incident.Executed_At__c;
        context.executionResult = incident.Execution_Result__c;
        context.createdCaseId = incident.Created_Case__c;
        context.canApprove = incident.Approval_Status__c == 'Pending Approval';
        context.canReject = incident.Approval_Status__c == 'Pending Approval';
        context.canExecute = incident.Approval_Status__c == 'Approved'
            && incident.Execution_Status__c != 'Executed';
        return context;
    }

    public class ApprovalContext {
        @AuraEnabled public Id incidentId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String policyDecision;
        @AuraEnabled public String recommendedAction;
        @AuraEnabled public String recommendationStatus;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Id approvedById;
        @AuraEnabled public Datetime approvedAt;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String executionStatus;
        @AuraEnabled public String executionAction;
        @AuraEnabled public Datetime executedAt;
        @AuraEnabled public String executionResult;
        @AuraEnabled public Id createdCaseId;
        @AuraEnabled public Boolean canApprove;
        @AuraEnabled public Boolean canReject;
        @AuraEnabled public Boolean canExecute;
    }
}