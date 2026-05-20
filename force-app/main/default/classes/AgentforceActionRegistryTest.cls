/**
 * AgentforceActionRegistryTest
 * Tests for the AgentforceActionRegistry strategy-pattern dispatcher
 * and HealTelemetryService feedback loop.
 *
 * @author  Tomcodex
 * @version 1.0 (Phase 6)
 */
@IsTest
private class AgentforceActionRegistryTest {

    @TestSetup
    static void setup() {
        SecurityGate.bypassForTests = true;

        Environment__c env = new Environment__c(
            Name = 'Registry Test Env',
            Org_Id__c = '00DRegistryTst01'
        );
        insert env;

        Integration_Log__c log = new Integration_Log__c(
            API_Name__c = 'Registry Test API',
            Status__c = 'Failed',
            Response_Time__c = 2000,
            Error_Message__c = 'Service unavailable'
        );
        insert log;

        Incident__c inc = new Incident__c(
            Severity__c = 'Critical',
            Status__c = 'New',
            Description__c = 'Agentforce registry test incident',
            Environment__c = env.Id,
            Integration_Log__c = log.Id
        );
        insert inc;

        // Create an AI Decision for telemetry tests
        AI_Decision__c decision = new AI_Decision__c(
            Incident__c = inc.Id,
            Root_Cause__c = 'Test root cause',
            Recommended_Action__c = 'Restart Service',
            Confidence_Score__c = 92,
            Impact_Level__c = 'High',
            Auto_Executed__c = false
        );
        insert decision;
    }

    @IsTest
    static void testDispatchRetry() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'Retry');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Retry should succeed');
        System.assert(result.detail.contains('Retry'), 'Detail should mention retry');
        System.assertNotEquals(null, result.executionTimeMs, 'Timing should be captured');
    }

    @IsTest
    static void testDispatchRestart() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'Restart Service');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(result.detail.contains('restart'), 'Detail should mention restart');
    }

    @IsTest
    static void testDispatchTokenRefresh() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'Token Refresh');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(result.detail.toLowerCase().contains('token'), 'Detail should mention token');
    }

    @IsTest
    static void testDispatchEscalate() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'Escalate to engineering');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(result.detail.contains('Case'), 'Escalation should create a Case');
    }

    @IsTest
    static void testDispatchUnknownAction() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'Deploy quantum patch to mainframe');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Unknown action should fail gracefully');
        System.assert(result.detail.contains('Unrecognized'), 'Should indicate unrecognized action');
    }

    @IsTest
    static void testDispatchNullInputs() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(null, null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.detail.contains('Invalid'), 'Should indicate invalid input');
    }

    @IsTest
    static void testNormalizedActionMatching() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        // Test fuzzy matching - "restart the failing service" should map to Restart Service
        AgentforceActionRegistry.ActionResult result =
            AgentforceActionRegistry.dispatch(incidentId, 'restart the failing service');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(result.detail.toLowerCase().contains('restart'), 'Should normalize to restart');
    }

    // ── Telemetry Tests ────────────────────────────────────────────────────────

    @IsTest
    static void testHealTelemetryRecordsOutcome() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        HealTelemetryService.recordHealOutcome(incidentId, true, 'Restart Service');
        Test.stopTest();

        AI_Decision__c decision = [
            SELECT Auto_Executed__c, Execution_Result__c, Executed_Action__c, Executed_At__c
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(true, decision.Auto_Executed__c, 'Auto_Executed should be true');
        System.assertEquals('Succeeded', decision.Execution_Result__c, 'Result should be Succeeded');
        System.assertEquals('Restart Service', decision.Executed_Action__c);
        System.assertNotEquals(null, decision.Executed_At__c, 'Timestamp should be set');
    }

    @IsTest
    static void testHealTelemetryFailedOutcome() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        HealTelemetryService.recordHealOutcome(incidentId, false, 'Retry');
        Test.stopTest();

        AI_Decision__c decision = [
            SELECT Execution_Result__c
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Failed', decision.Execution_Result__c);
    }

    @IsTest
    static void testHealTelemetryNullIncident() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        // Should not throw — graceful null handling
        HealTelemetryService.recordHealOutcome(null, true, 'Retry');
        Test.stopTest();

        // No assertion needed — just verifying no exception
    }

    @IsTest
    static void testGetHealMetrics() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        HealTelemetryService.HealMetrics metrics = HealTelemetryService.getHealMetrics();
        Test.stopTest();

        System.assertNotEquals(null, metrics);
        System.assert(metrics.totalDecisions >= 1, 'Should have at least 1 decision from setup');
    }

    @IsTest
    static void testGetDecisionsForIncident() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        List<AI_Decision__c> decisions = HealTelemetryService.getDecisionsForIncident(incidentId);
        Test.stopTest();

        System.assert(!decisions.isEmpty(), 'Should return at least 1 decision');
        System.assertEquals('Restart Service', decisions[0].Recommended_Action__c);
    }

    @IsTest
    static void testGetDecisionsForNullIncident() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        List<AI_Decision__c> decisions = HealTelemetryService.getDecisionsForIncident(null);
        Test.stopTest();

        System.assert(decisions.isEmpty(), 'Null incident should return empty list');
    }

    // ── Router Integration Test ────────────────────────────────────────────────

    @IsTest
    static void testRouterHandoffToAgentforce() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        Test.startTest();
        SelfHealingEngine.HealResult result =
            ZentomAgentforceRouter.handoffToAgentforce(incidentId, 'Restart Service');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assert(result.actionTaken.contains('Agentforce'));
    }

    @IsTest
    static void testRouterInvocableExecuteAction() {
        SecurityGate.bypassForTests = true;
        Id incidentId = getTestIncidentId();

        ZentomAgentforceRouter.ExecutionRequest req = new ZentomAgentforceRouter.ExecutionRequest();
        req.incidentId = incidentId;
        req.proposedAction = 'Retry the integration';

        Test.startTest();
        ZentomAgentforceRouter.executeAction(new List<ZentomAgentforceRouter.ExecutionRequest>{ req });
        Test.stopTest();

        // Verify telemetry was recorded
        AI_Decision__c decision = [
            SELECT Auto_Executed__c, Execution_Result__c
            FROM   AI_Decision__c
            WHERE  Incident__c = :incidentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(true, decision.Auto_Executed__c);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    private static Id getTestIncidentId() {
        return [
            SELECT Id FROM Incident__c
            WHERE Severity__c = 'Critical'
            AND Status__c != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ].Id;
    }
}

