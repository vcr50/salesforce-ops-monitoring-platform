public with sharing class ZentomExecutionController {
    @AuraEnabled
    public static ExecutionResult executeApprovedAction(Id incidentId) {
        return createCaseFromIncident(incidentId);
    }

    @AuraEnabled
    public static ExecutionResult createCaseFromIncident(Id incidentId) {
        Sentinel_Incident__c incident = loadApprovedIncident(incidentId);

        try {
            Case createdCase = new Case(
                Subject = buildCaseSubject(incident),
                Description = buildCaseDescription(incident),
                Priority = isHighPriority(incident.Risk_Level__c) ? 'High' : 'Medium',
                Origin = getSafeCaseOrigin()
            );
            insert createdCase;

            incident.Status__c = 'Action Created';
            incident.Execution_Status__c = 'Executed';
            incident.Execution_Action__c = 'CREATE_CASE';
            incident.Executed_At__c = System.now();
            incident.Execution_Result__c = 'Created Salesforce Case ' + createdCase.Id;
            incident.Created_Case__c = createdCase.Id;
            incident.Next_Action__c = 'Salesforce Case created for admin review.';
            update incident;

            createAuditLog(
                incident.Id,
                'RUNBOOK_ACTION_EXECUTED',
                'CREATE_CASE',
                'Created Case Id: ' + createdCase.Id
            );

            createAuditLog(
                incident.Id,
                'CASE_CREATED',
                String.valueOf(createdCase.Id),
                'Case Number pending assignment. Case Id: ' + createdCase.Id
            );

            ExecutionResult result = new ExecutionResult();
            result.incidentId = incident.Id;
            result.caseId = createdCase.Id;
            result.status = incident.Status__c;
            result.executionStatus = incident.Execution_Status__c;
            result.message = incident.Execution_Result__c;
            return result;
        } catch (Exception e) {
            incident.Execution_Status__c = 'Failed';
            incident.Execution_Action__c = 'CREATE_CASE';
            incident.Execution_Result__c = e.getMessage();
            incident.Next_Action__c = 'Case creation failed. Review execution audit log.';
            update incident;

            createAuditLog(
                incident.Id,
                'ACTION_FAILED',
                'CREATE_CASE_FAILED',
                e.getMessage()
            );

            throw new AuraHandledException('Case creation failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ExecutionResult createTaskFromIncident(Id incidentId) {
        throw new AuraHandledException('Task execution is not enabled in Milestone 6.');
    }

    public static void executeAction(Id incidentId, String action, Decimal confidence, String executionMode) {
        if (confidence < 80.0) {
            throw new AuraHandledException('Confidence too low (' + confidence + ') for autonomous execution. Blocked at final gate.');
        }

        if (executionMode != 'AUTONOMOUS_EXECUTION') {
            throw new AuraHandledException('Execution blocked. Policy Mode is: ' + executionMode);
        }

        throw new AuraHandledException(
            'Autonomous Agentforce execution is isolated in experimental metadata. ' +
            'Use executeApprovedAction for the MVP Case creation path.'
        );
    }

    private static Sentinel_Incident__c loadApprovedIncident(Id incidentId) {
        if (incidentId == null) {
            throw new AuraHandledException('Incident id is required.');
        }

        List<Sentinel_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Error_Message__c, Risk_Score__c,
                Risk_Level__c, Policy_Decision__c, AI_Summary__c, Root_Cause__c,
                Recommended_Action__c, Runbook_Key__c, Runbook_Title__c,
                Runbook_Description__c, Runbook_Steps__c, Approval_Status__c,
                Execution_Status__c
            FROM Sentinel_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        if (incidents.isEmpty()) {
            throw new AuraHandledException('Incident was not found.');
        }

        Sentinel_Incident__c incident = incidents[0];
        if (incident.Approval_Status__c != 'Approved') {
            throw new AuraHandledException('Incident must be approved before execution.');
        }

        if (incident.Execution_Status__c == 'Executed') {
            throw new AuraHandledException('Approved action has already been executed.');
        }

        return incident;
    }

    private static String buildCaseSubject(Sentinel_Incident__c incident) {
        return '[SentinelFlow] ' + incident.Incident_Type__c + ' - ' + incident.Risk_Level__c;
    }

    private static String buildCaseDescription(Sentinel_Incident__c incident) {
        return 'Zentom AI Summary:\n' + nullToBlank(incident.AI_Summary__c) + '\n\n' +
            'Root Cause:\n' + nullToBlank(incident.Root_Cause__c) + '\n\n' +
            'Recommended Action:\n' + nullToBlank(incident.Recommended_Action__c) + '\n\n' +
            'Runbook:\n' + nullToBlank(incident.Runbook_Key__c) + ' - ' +
                nullToBlank(incident.Runbook_Title__c) + '\n\n' +
            'Runbook Steps:\n' + nullToBlank(incident.Runbook_Steps__c) + '\n\n' +
            'Risk:\n' + String.valueOf(incident.Risk_Score__c) + ' / ' +
                nullToBlank(incident.Risk_Level__c) + '\n\n' +
            'Policy:\n' + nullToBlank(incident.Policy_Decision__c) + '\n\n' +
            'Original Error Message: ' + nullToBlank(incident.Error_Message__c);
    }

    private static Boolean isHighPriority(String riskLevel) {
        return riskLevel == 'CRITICAL' || riskLevel == 'HIGH';
    }

    private static String getSafeCaseOrigin() {
        for (Schema.PicklistEntry entry : Case.Origin.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == 'SentinelFlow') {
                return 'SentinelFlow';
            }
        }

        return 'Web';
    }

    private static String nullToBlank(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static void createAuditLog(
        Id incidentId,
        String eventType,
        String decision,
        String responsePayload
    ) {
        insert new Sentinel_Audit_Log__c(
            Incident__c = incidentId,
            Event_Type__c = eventType,
            Decision__c = decision,
            Response_Payload__c = responsePayload,
            Created_By_System__c = true,
            Trace_Id__c = String.valueOf(incidentId)
        );
    }

    public class ExecutionResult {
        @AuraEnabled public Id incidentId;
        @AuraEnabled public Id caseId;
        @AuraEnabled public String status;
        @AuraEnabled public String executionStatus;
        @AuraEnabled public String message;
    }
}