/**
 * ZentomOrchestratorTest
 * End-to-end integration test for the full Zentom orchestration pipeline.
 * Validates that all 8 engines work together through orchestrateIncident().
 */
@IsTest
private class ZentomOrchestratorTest {

    @TestSetup
    static void setup() {
        Incident__c inc = new Incident__c(
            Severity__c = 'Critical',
            Description__c = 'Primary API gateway returning 503 errors consistently.',
            Status__c = 'New'
        );
        insert inc;
    }

    @IsTest
    static void testOrchestrateIncident_HighARR_BlocksExecution() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        ZentomAIClient.ZentomDecision decision = ZentomAIClient.orchestrateIncident(
            inc.Id,
            'API gateway is returning 503 errors. Diagnose and recommend.',
            'SYSTEM_FAILURE',
            'Diagnosis'
        );
        Test.stopTest();

        // The mock fallback returns confidence 92 and action 'Restart Service'
        // But the high ARR ($150k default) should trigger Guardian Gate
        System.assertNotEquals(null, decision, 'Decision should not be null');
        System.assertNotEquals(null, decision.proposed_action, 'Proposed action should exist');
        System.assertNotEquals(null, decision.confidence_score, 'Confidence should exist');

        // Verify replay log was created
        List<Zentom_Replay_Log__c> replayLogs = [SELECT Id, Policy_Mode__c FROM Zentom_Replay_Log__c];
        System.assertEquals(1, replayLogs.size(), 'Replay log should be created');
        System.assertEquals('HUMAN_APPROVAL_REQUIRED', replayLogs[0].Policy_Mode__c,
            'High ARR should trigger Guardian Gate → HUMAN_APPROVAL_REQUIRED');
    }

    @IsTest
    static void testOrchestrateIncident_ReturnsDecisionFields() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        ZentomAIClient.ZentomDecision decision = ZentomAIClient.orchestrateIncident(
            inc.Id,
            'Diagnose the incident.',
            'SYSTEM_FAILURE',
            'Diagnosis'
        );
        Test.stopTest();

        System.assertNotEquals(null, decision.recommendation, 'Recommendation should be populated');
        System.assertNotEquals(null, decision.rationale, 'Rationale should be populated');
        System.assert(decision.confidence_score > 0, 'Confidence should be a positive integer');
    }
}

