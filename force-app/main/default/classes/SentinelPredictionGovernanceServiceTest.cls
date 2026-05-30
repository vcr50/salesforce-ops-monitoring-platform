@IsTest
private class SentinelPredictionGovernanceServiceTest {

    @IsTest
    static void testCreateApprovalSuccess() {
        // Create test prediction
        Sentinel_Prediction__c pred = new Sentinel_Prediction__c(
            Prediction_Score__c = 85.0,
            Confidence_Score__c = 90.0,
            Status__c = 'Critical',
            Summary__c = 'High probability of CRM failure',
            Explanation__c = 'Integration errors spiked on Zoho API',
            Operator_Decision__c = 'Pending'
        );
        insert pred;

        Test.startTest();
        Id incidentId = SentinelPredictionGovernanceService.createApprovalFromPrediction(pred.Id);
        Test.stopTest();

        // Verify incident created and mapped correctly
        System.assertNotEquals(null, incidentId, 'Incident ID should not be null');
        Sentinel_Incident__c incident = [
            SELECT Id, Incident_Type__c, Risk_Level__c, AI_Confidence__c,
                   AI_Reasoning_Status__c, Approval_Status__c, Recommended_Action__c,
                   AI_Explanation__c, AI_Summary__c, Risk_Score__c, Source__c,
                   Status__c, Source_Prediction__c
            FROM Sentinel_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        System.assertEquals('Predicted Anomaly', incident.Incident_Type__c);
        System.assertEquals('CRITICAL', incident.Risk_Level__c);
        System.assertEquals(90.0, incident.AI_Confidence__c);
        System.assertEquals('Prediction-Triggered', incident.AI_Reasoning_Status__c);
        System.assertEquals('Pending Approval', incident.Approval_Status__c);
        System.assertEquals('Integration errors spiked on Zoho API', incident.Recommended_Action__c);
        System.assertEquals('Integration errors spiked on Zoho API', incident.AI_Explanation__c);
        System.assertEquals('High probability of CRM failure', incident.AI_Summary__c);
        System.assertEquals(85.0, incident.Risk_Score__c);
        System.assertEquals('Prediction Engine', incident.Source__c);
        System.assertEquals('Approval Required', incident.Status__c);
        System.assertEquals(pred.Id, incident.Source_Prediction__c);

        // Verify prediction linked back
        Sentinel_Prediction__c updatedPred = [
            SELECT Id, Incident__c, Operator_Decision__c
            FROM Sentinel_Prediction__c
            WHERE Id = :pred.Id
            LIMIT 1
        ];
        System.assertEquals(incidentId, updatedPred.Incident__c);
        System.assertEquals('Pending', updatedPred.Operator_Decision__c);

        // Verify audit log created
        List<Sentinel_Audit_Log__c> auditLogs = [
            SELECT Event_Type__c, Incident__c, Request_Payload__c
            FROM Sentinel_Audit_Log__c
            ORDER BY CreatedDate DESC
        ];
        System.assert(!auditLogs.isEmpty(), 'Audit logs should be created');
        System.assertEquals('Prediction Approval Requested', auditLogs[0].Event_Type__c);
    }

    @IsTest
    static void testCreateApprovalWarningsAndExceptions() {
        // Warning prediction
        Sentinel_Prediction__c warningPred = new Sentinel_Prediction__c(
            Prediction_Score__c = 55.0,
            Confidence_Score__c = 80.0,
            Status__c = 'Warning',
            Summary__c = 'Timeout warning',
            Explanation__c = 'Response time > 5000ms',
            Operator_Decision__c = 'Pending'
        );
        insert warningPred;

        Id warningIncId = SentinelPredictionGovernanceService.createApprovalFromPrediction(warningPred.Id);
        Sentinel_Incident__c warningInc = [SELECT Risk_Level__c FROM Sentinel_Incident__c WHERE Id = :warningIncId];
        System.assertEquals('HIGH', warningInc.Risk_Level__c);

        // Dismissed prediction cannot request approval
        Sentinel_Prediction__c dismissedPred = new Sentinel_Prediction__c(
            Operator_Decision__c = 'Dismissed'
        );
        insert dismissedPred;

        try {
            SentinelPredictionGovernanceService.createApprovalFromPrediction(dismissedPred.Id);
            System.assert(false, 'Should have thrown exception for dismissed prediction');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('dismissed'), 'Expected exception message');
        }

        // Already decided (e.g. Confirmed) cannot request approval
        Sentinel_Prediction__c confirmedPred = new Sentinel_Prediction__c(
            Operator_Decision__c = 'Confirmed'
        );
        insert confirmedPred;

        try {
            SentinelPredictionGovernanceService.createApprovalFromPrediction(confirmedPred.Id);
            System.assert(false, 'Should have thrown exception for confirmed prediction');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('Pending status'), 'Expected exception message');
        }

        // Duplicate approval request checks
        warningPred.Incident__c = warningIncId;
        update warningPred;

        try {
            SentinelPredictionGovernanceService.createApprovalFromPrediction(warningPred.Id);
            System.assert(false, 'Should have thrown exception for duplicate request');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('Duplicate requests'), 'Expected exception message');
        }

        // Non-existent ID exception
        try {
            SentinelPredictionGovernanceService.createApprovalFromPrediction(null);
            System.assert(false, 'Should have thrown exception for null ID');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('required'), 'Expected exception message');
        }

        Id fakeId = warningPred.Id;
        delete warningPred;
        try {
            SentinelPredictionGovernanceService.createApprovalFromPrediction(fakeId);
            System.assert(false, 'Should have thrown exception for non-existent ID');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('not found'), 'Expected exception message');
        }
    }

    @IsTest
    static void testUpdatePredictionDecisionAndTerminals() {
        Sentinel_Prediction__c pred = new Sentinel_Prediction__c(
            Operator_Decision__c = 'Pending',
            Prediction_Score__c = 75
        );
        insert pred;

        SentinelPredictionGovernanceService.updatePredictionDecision(pred.Id, 'Confirmed');

        Sentinel_Prediction__c updated = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred.Id];
        System.assertEquals('Confirmed', updated.Operator_Decision__c);

        // Cannot overwrite terminal decision
        try {
            SentinelPredictionGovernanceService.updatePredictionDecision(pred.Id, 'Dismissed');
            System.assert(false, 'Should have thrown exception for decided prediction');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('already been decided'), 'Expected exception message');
        }

        // Invalid decision
        try {
            SentinelPredictionGovernanceService.updatePredictionDecision(pred.Id, 'Invalid');
            System.assert(false, 'Should have thrown exception for invalid decision');
        } catch (SentinelPredictionGovernanceService.GovernanceException e) {
            System.assert(e.getMessage().contains('Invalid decision value'), 'Expected exception message');
        }
    }

    @IsTest
    static void testOperatorActions() {
        Sentinel_Prediction__c pred1 = new Sentinel_Prediction__c(Operator_Decision__c = 'Pending');
        Sentinel_Prediction__c pred2 = new Sentinel_Prediction__c(Operator_Decision__c = 'Pending');
        Sentinel_Prediction__c pred3 = new Sentinel_Prediction__c(Operator_Decision__c = 'Pending');
        insert new List<Sentinel_Prediction__c>{pred1, pred2, pred3};

        SentinelPredictionGovernanceService.dismissPrediction(pred1.Id);
        Sentinel_Prediction__c res1 = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred1.Id];
        System.assertEquals('Dismissed', res1.Operator_Decision__c);

        SentinelPredictionGovernanceService.markPredictionUseful(pred2.Id);
        Sentinel_Prediction__c res2 = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred2.Id];
        System.assertEquals('Useful', res2.Operator_Decision__c);

        SentinelPredictionGovernanceService.markPredictionNoisy(pred3.Id);
        Sentinel_Prediction__c res3 = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred3.Id];
        System.assertEquals('False Positive', res3.Operator_Decision__c);
    }

    @IsTest
    static void testIncidentTriggerPropagation() {
        Sentinel_Prediction__c pred = new Sentinel_Prediction__c(
            Operator_Decision__c = 'Pending',
            Prediction_Score__c = 85.0
        );
        insert pred;

        Sentinel_Incident__c inc = new Sentinel_Incident__c(
            Incident_Type__c = 'Predicted Anomaly',
            Approval_Status__c = 'Pending Approval',
            Source_Prediction__c = pred.Id
        );
        insert inc;

        // Verify updating incident to Approved triggers prediction to Confirmed
        inc.Approval_Status__c = 'Approved';
        
        Test.startTest();
        update inc;
        Test.stopTest();

        Sentinel_Prediction__c res = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred.Id];
        System.assertEquals('Confirmed', res.Operator_Decision__c);
    }

    @IsTest
    static void testIncidentTriggerPropagationRejection() {
        Sentinel_Prediction__c pred = new Sentinel_Prediction__c(
            Operator_Decision__c = 'Pending',
            Prediction_Score__c = 85.0
        );
        insert pred;

        Sentinel_Incident__c inc = new Sentinel_Incident__c(
            Incident_Type__c = 'Predicted Anomaly',
            Approval_Status__c = 'Pending Approval',
            Source_Prediction__c = pred.Id
        );
        insert inc;

        // Verify updating incident to Rejected triggers prediction to Dismissed
        inc.Approval_Status__c = 'Rejected';
        
        Test.startTest();
        update inc;
        Test.stopTest();

        Sentinel_Prediction__c res = [SELECT Operator_Decision__c FROM Sentinel_Prediction__c WHERE Id = :pred.Id];
        System.assertEquals('Dismissed', res.Operator_Decision__c);
    }
}
