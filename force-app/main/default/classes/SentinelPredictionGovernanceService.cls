public with sharing class SentinelPredictionGovernanceService {

    // =========================================================================
    // Milestone 59B — Prediction-to-Approval Governance Service
    // =========================================================================
    // Purpose: Creates governed approval records from Sentinel_Prediction__c
    //          cards and enforces all safety boundaries from the 59A design.
    //
    // Safety Rule: This service creates approval records ONLY.
    //              It cannot execute, approve, reject, or remediate anything.
    //              Human approval via Guardian Gate remains mandatory.
    // =========================================================================

    // ------------------------------------------------------------------
    // Custom Exception
    // ------------------------------------------------------------------
    public class GovernanceException extends Exception {}

    // ------------------------------------------------------------------
    // createApprovalFromPrediction
    // Called when operator clicks "Request Approval" on a prediction card.
    // Creates Sentinel_Incident__c (Type: Predicted Anomaly) in the
    // Guardian Gate queue and logs a Sentinel_Audit_Log__c record.
    // ------------------------------------------------------------------
    @AuraEnabled
    public static Id createApprovalFromPrediction(Id predictionId) {
        if (predictionId == null) {
            throw new GovernanceException('Prediction ID is required.');
        }

        // Fetch prediction — validate it exists and is actionable
        List<Sentinel_Prediction__c> predictions = [
            SELECT Id, Prediction_Score__c, Confidence_Score__c, Status__c,
                   Summary__c, Explanation__c, Operator_Decision__c, Incident__c
            FROM Sentinel_Prediction__c
            WHERE Id = :predictionId
            LIMIT 1
        ];

        if (predictions.isEmpty()) {
            throw new GovernanceException('Prediction record not found: ' + predictionId);
        }

        Sentinel_Prediction__c pred = predictions[0];

        // Safety Guard 1: Dismissed predictions cannot request approval
        if (pred.Operator_Decision__c == 'Dismissed') {
            throw new GovernanceException(
                'Cannot request approval for a dismissed prediction. ' +
                'Dismissed status is terminal.'
            );
        }

        // Safety Guard 2: Only Pending predictions can initiate approval
        if (pred.Operator_Decision__c != 'Pending') {
            throw new GovernanceException(
                'Approval can only be requested for predictions with Pending status. ' +
                'Current status: ' + pred.Operator_Decision__c
            );
        }

        // Safety Guard 3: Prevent duplicate approval requests (already linked)
        if (pred.Incident__c != null) {
            throw new GovernanceException(
                'An approval request already exists for this prediction (Incident: ' +
                pred.Incident__c + '). Duplicate requests are not permitted.'
            );
        }

        // Map prediction risk level to incident risk level picklist
        String riskLevel = 'MEDIUM';
        if (pred.Status__c == 'Critical') {
            riskLevel = 'CRITICAL';
        } else if (pred.Status__c == 'Warning') {
            riskLevel = 'HIGH';
        }

        // Build the Sentinel_Incident__c (Guardian Gate approval record)
        Sentinel_Incident__c incident = new Sentinel_Incident__c();
        incident.Incident_Type__c     = 'Predicted Anomaly';
        incident.Risk_Level__c        = riskLevel;
        incident.AI_Confidence__c     = pred.Confidence_Score__c;
        incident.AI_Reasoning_Status__c = 'Prediction-Triggered';
        incident.Approval_Status__c   = 'Pending Approval';
        incident.Recommended_Action__c = pred.Explanation__c;
        incident.AI_Explanation__c    = pred.Explanation__c;
        incident.AI_Summary__c        = pred.Summary__c;
        incident.Risk_Score__c        = pred.Prediction_Score__c;
        incident.Source__c            = 'Prediction Engine';
        incident.Source_Prediction__c = pred.Id;
        incident.Status__c            = 'Approval Required';

        insert as user incident;

        // Link the prediction back to the incident
        pred.Incident__c           = incident.Id;
        pred.Operator_Decision__c  = 'Pending'; // stays Pending — awaiting human decision

        update as user pred;

        // Audit log: Prediction Approval Requested
        logAuditEvent(
            incident.Id,
            'Prediction Approval Requested',
            'Prediction ID: ' + predictionId + ' | Score: ' + pred.Prediction_Score__c + '% | Status: ' + pred.Status__c +
            ' | Incident created: ' + incident.Id
        );

        return incident.Id;
    }

    // ------------------------------------------------------------------
    // updatePredictionDecision
    // Called after Guardian Gate approves or rejects the incident.
    // Updates Operator_Decision__c on the prediction and adjusts trust.
    // ------------------------------------------------------------------
    @AuraEnabled
    public static void updatePredictionDecision(Id predictionId, String decision) {
        if (predictionId == null || String.isBlank(decision)) {
            throw new GovernanceException('Prediction ID and decision are required.');
        }

        Set<String> validDecisions = new Set<String>{
            'Confirmed', 'Dismissed', 'Useful', 'False Positive'
        };
        if (!validDecisions.contains(decision)) {
            throw new GovernanceException(
                'Invalid decision value: ' + decision +
                '. Must be one of: Confirmed, Dismissed, Useful, False Positive.'
            );
        }

        List<Sentinel_Prediction__c> predictions = [
            SELECT Id, Operator_Decision__c, Status__c, Prediction_Score__c, Incident__c
            FROM Sentinel_Prediction__c
            WHERE Id = :predictionId
            LIMIT 1
        ];

        if (predictions.isEmpty()) {
            throw new GovernanceException('Prediction record not found: ' + predictionId);
        }

        Sentinel_Prediction__c pred = predictions[0];

        // Safety Guard: Cannot re-decide an already decided prediction
        if (pred.Operator_Decision__c != 'Pending') {
            throw new GovernanceException(
                'Prediction has already been decided: ' + pred.Operator_Decision__c +
                '. Decisions are terminal and cannot be overwritten.'
            );
        }

        pred.Operator_Decision__c = decision;
        update as user pred;

        // Determine audit event type from decision
        String auditEventType = 'Prediction Decision Updated';
        if (decision == 'Confirmed') {
            auditEventType = 'Prediction Approval Confirmed';
        } else if (decision == 'Dismissed') {
            auditEventType = (pred.Incident__c != null) ? 'Prediction Approval Rejected' : 'Prediction Dismissed';
        } else if (decision == 'Useful') {
            auditEventType = 'Prediction Marked Useful';
        } else if (decision == 'False Positive') {
            auditEventType = 'Prediction Marked False Positive';
        }

        logAuditEvent(
            pred.Incident__c,
            auditEventType,
            'Prediction ID: ' + predictionId + ' | Decision: ' + decision + ' | Score: ' + pred.Prediction_Score__c + '%'
        );
    }

    // ------------------------------------------------------------------
    // dismissPrediction
    // Called when operator clicks "Dismiss" on a prediction card.
    // ------------------------------------------------------------------
    @AuraEnabled
    public static void dismissPrediction(Id predictionId) {
        updatePredictionDecision(predictionId, 'Dismissed');
    }

    // ------------------------------------------------------------------
    // markPredictionUseful
    // Called when operator clicks "Mark Useful".
    // ------------------------------------------------------------------
    @AuraEnabled
    public static void markPredictionUseful(Id predictionId) {
        updatePredictionDecision(predictionId, 'Useful');
    }

    // ------------------------------------------------------------------
    // markPredictionNoisy
    // Called when operator clicks "Mark Noisy" (False Positive).
    // ------------------------------------------------------------------
    @AuraEnabled
    public static void markPredictionNoisy(Id predictionId) {
        updatePredictionDecision(predictionId, 'False Positive');
    }

    // ------------------------------------------------------------------
    // Private helper: write a Sentinel_Audit_Log__c record
    // ------------------------------------------------------------------
    private static void logAuditEvent(Id recordId, String eventType, String details) {
        try {
            Sentinel_Audit_Log__c auditEntry = new Sentinel_Audit_Log__c();
            auditEntry.Event_Type__c        = eventType;
            auditEntry.Incident__c          = recordId;
            auditEntry.Request_Payload__c   = details;
            auditEntry.Created_By_System__c = false;
            insert as user auditEntry;
        } catch (Exception e) {
            // Audit failure must not block the primary operation
            System.debug(LoggingLevel.WARN,
                '[SentinelPredictionGovernanceService] Audit log insert failed: ' +
                e.getMessage());
        }
    }
}
