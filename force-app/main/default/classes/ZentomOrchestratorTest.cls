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

        System.assertNotEquals(null, decision, 'Decision should not be null');
        System.assertEquals('Escalate', decision.proposed_action, 'Proposed action should be Escalate');
        System.assertEquals(50, decision.confidence_score, 'Confidence should be 50');
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