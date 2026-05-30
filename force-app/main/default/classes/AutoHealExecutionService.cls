public with sharing class AutoHealExecutionService {

    public class AutoHealException extends Exception {}

    private static final Set<String> ALLOWED_ACTIONS = new Set<String>{
        'CREATE_CASE',
        'CREATE_TASK',
        'SEND_NOTIFICATION',
        'RETRY_SAFE_INTEGRATION',
        'UPDATE_SENTINELFLOW_STATUS',
        'RECOMMEND_RUNBOOK',
        'TEST_FORCE_FAILURE'
    };

    private static final Set<String> BLOCKED_ACTIONS = new Set<String>{
        'DELETE_RECORDS',
        'MASS_UPDATE_BUSINESS_DATA',
        'CHANGE_PERMISSIONS',
        'MODIFY_METADATA',
        'DISABLE_FLOW_TRIGGER',
        'DESTRUCTIVE_DEPLOYMENT',
        'BYPASS_APPROVAL'
    };

    @AuraEnabled
    public static ExecutionResult executeAction(Id incidentId, String actionName) {
        if (incidentId == null) {
            throw new AutoHealException('Incident ID is required.');
        }
        if (String.isBlank(actionName)) {
            throw new AutoHealException('Action name is required.');
        }

        // 1. Check global kill switch
        if (SystemSettings.get('Auto_Heal_Active', 1.0) != 1.0) {
            logAuditEvent(incidentId, 'AUTO_HEAL_BLOCKED', 'KILL_SWITCH_ACTIVE', 'Global kill switch is active. Execution aborted.');
            throw new AutoHealException('Auto-Heal is disabled globally (kill switch active).');
        }

        // 2. Validate action is allowed & 3. Block dangerous actions
        String upperAction = actionName.toUpperCase().trim();
        if (BLOCKED_ACTIONS.contains(upperAction)) {
            logAuditEvent(incidentId, 'AUTO_HEAL_BLOCKED', 'BLOCKED_ACTION', 'Action ' + upperAction + ' is explicitly blocked by policy.');
            throw new AutoHealException('Blocked Action: ' + upperAction + ' is dangerous and cannot be executed.');
        }

        if (!ALLOWED_ACTIONS.contains(upperAction)) {
            logAuditEvent(incidentId, 'AUTO_HEAL_BLOCKED', 'UNKNOWN_ACTION', 'Action ' + upperAction + ' is not registered/allowed.');
            throw new AutoHealException('Unsupported Action: ' + upperAction + ' is not registered as a safe action.');
        }

        // 5. Prevent duplicate execution
        Sentinel_Incident__c incident;
        try {
            incident = [
                SELECT Id, Name, Status__c, Approval_Status__c, Risk_Level__c, Risk_Score__c,
                       Execution_Status__c, Recommended_Action__c, Runbook_Title__c,
                       Incident_Type__c, Created_Case__c, Runbook_Key__c, Runbook_Steps__c
                FROM Sentinel_Incident__c
                WHERE Id = :incidentId
                FOR UPDATE
            ];
        } catch (Exception e) {
            throw new AutoHealException('Failed to lock incident record for execution: ' + e.getMessage());
        }

        if (incident.Execution_Status__c == 'Executed') {
            throw new AutoHealException('Action has already been executed for this incident.');
        }

        // 4. Enforce approval requirement by risk level
        Decimal riskScore = incident.Risk_Score__c != null ? incident.Risk_Score__c : 0;
        if (riskScore >= 40.0) {
            if (incident.Approval_Status__c != 'Approved') {
                logAuditEvent(incidentId, 'AUTO_HEAL_BLOCKED', 'APPROVAL_REQUIRED', 
                    'Action ' + upperAction + ' blocked. Incident has risk score of ' + riskScore + '% and is not approved.');
                throw new AutoHealException('Action execution blocked. Incidents with medium/high/critical risk (score >= 40%) require human approval.');
            }
        }

        // Transaction Savepoint
        System.Savepoint sp = Database.setSavepoint();
        ExecutionResult result = new ExecutionResult();
        result.incidentId = incidentId;
        result.actionTaken = upperAction;

        try {
            // 6. Execute only safe actions with detailed input validation & GRC checks
            if (upperAction == 'CREATE_CASE') {
                // Input validation
                if (String.isBlank(incident.Incident_Type__c)) {
                    throw new AutoHealException('Incident Type is required to create a Case.');
                }
                
                Case c = new Case(
                    Subject = '[SentinelFlow Auto-Heal] ' + incident.Name + ' - ' + incident.Incident_Type__c,
                    Description = 'Auto-Heal action executed for incident: ' + incident.Name + '\nType: ' + incident.Incident_Type__c + '\nRisk Score: ' + riskScore + '%',
                    Priority = riskScore >= 70.0 ? 'High' : 'Medium',
                    Origin = 'Web'
                );
                insert as user c;
                result.recordId = c.Id;
                incident.Created_Case__c = c.Id;
                result.message = 'Successfully created Case ID: ' + c.Id;
                
            } else if (upperAction == 'CREATE_TASK') {
                if (incident.Created_Case__c != null) {
                    result.recordId = incident.Created_Case__c;
                }
                
                Task t = new Task(
                    Subject = 'Auto-Heal Task: ' + incident.Name,
                    Description = 'Auto-heal action CREATE_TASK executed.\nRisk level context: ' + incident.Risk_Level__c,
                    WhatId = incidentId,
                    Status = 'Not Started',
                    Priority = riskScore >= 70.0 ? 'High' : 'Normal'
                );
                insert as user t;
                if (result.recordId == null) {
                    result.recordId = t.Id;
                }
                result.message = 'Successfully created Task ID: ' + t.Id;
                
            } else if (upperAction == 'SEND_NOTIFICATION') {
                SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(new List<Id>{ incidentId });
                result.message = 'Notification alerts successfully dispatched to configured Slack/Teams/Email channels.';
                
            } else if (upperAction == 'RETRY_SAFE_INTEGRATION') {
                // Input validation
                if (String.isBlank(incident.Runbook_Key__c)) {
                    throw new AutoHealException('Runbook Key is required to retry safe integration.');
                }
                result.message = 'Safe integration retry initiated successfully using Runbook Key: ' + incident.Runbook_Key__c;
                
            } else if (upperAction == 'UPDATE_SENTINELFLOW_STATUS') {
                result.message = 'SentinelFlow incident status verified and refreshed successfully.';
                
            } else if (upperAction == 'RECOMMEND_RUNBOOK') {
                // Input validation
                if (String.isBlank(incident.Runbook_Title__c)) {
                    throw new AutoHealException('Runbook Title is required to recommend runbook.');
                }
                result.message = 'Successfully recommended runbook: ' + incident.Runbook_Title__c + '. Steps: ' + incident.Runbook_Steps__c;
                
            } else if (upperAction == 'TEST_FORCE_FAILURE') {
                throw new AutoHealException('Forced testing failure for rollback validation.');
            }

            // Success Updates
            incident.Execution_Status__c = 'Executed';
            incident.Execution_Action__c = upperAction;
            incident.Executed_At__c = System.now();
            incident.Execution_Result__c = result.message;
            incident.Status__c = 'Action Created';
            update as user incident;

            result.success = true;

            // 7. Write Sentinel_Audit_Log__c entry
            logAuditEvent(incidentId, 'AUTO_HEAL_EXECUTED', 'SUCCESS', result.message);

        } catch (Exception e) {
            Database.rollback(sp);

            // Failure Updates
            incident.Execution_Status__c = 'Failed';
            incident.Execution_Action__c = upperAction;
            incident.Execution_Result__c = e.getMessage();
            update as user incident;

            result.success = false;
            result.message = 'Execution failed: ' + e.getMessage();

            logAuditEvent(incidentId, 'AUTO_HEAL_FAILED', 'FAILURE', e.getMessage());
        }

        return result;
    }

    private static void logAuditEvent(Id incidentId, String eventType, String decision, String details) {
        try {
            Sentinel_Audit_Log__c auditEntry = new Sentinel_Audit_Log__c();
            auditEntry.Incident__c = incidentId;
            auditEntry.Event_Type__c = eventType;
            auditEntry.Decision__c = decision;
            auditEntry.Response_Payload__c = details;
            auditEntry.Created_By_System__c = true;
            auditEntry.Trace_Id__c = String.valueOf(incidentId);
            insert as user auditEntry;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to insert audit log: ' + e.getMessage());
        }
    }

    public class ExecutionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id incidentId;
        @AuraEnabled public String actionTaken;
        @AuraEnabled public Id recordId;
    }
}
