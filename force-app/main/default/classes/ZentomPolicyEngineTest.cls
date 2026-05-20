/**
 * Test class for ZentomPolicyEngine
 */
@IsTest
private class ZentomPolicyEngineTest {

    @IsTest
    static void testEvaluateAction_Destructive() {
        Test.startTest();
        ZentomPolicyEngine.PolicyEvaluation result = ZentomPolicyEngine.evaluateAction('Delete Opportunity', 10.0, 'Sales');
        Test.stopTest();
        
        System.assertEquals(ZentomPolicyEngine.ExecutionMode.BLOCKED_BY_POLICY, result.mode, 'Destructive actions should be blocked');
        System.assertEquals(false, result.requiresApproval, 'Blocked actions do not require approval');
    }

    @IsTest
    static void testEvaluateAction_HighRiskWorkflow() {
        Test.startTest();
        ZentomPolicyEngine.PolicyEvaluation result = ZentomPolicyEngine.evaluateAction('Retry Transaction', 20.0, 'Payment');
        Test.stopTest();
        
        System.assertEquals(ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED, result.mode, 'Financial workflows require approval');
        System.assertEquals(true, result.requiresApproval, 'Approval is required');
    }

    @IsTest
    static void testEvaluateAction_HighRiskScore() {
        Test.startTest();
        ZentomPolicyEngine.PolicyEvaluation result = ZentomPolicyEngine.evaluateAction('Sync Record', 80.0, 'Sales');
        Test.stopTest();
        
        System.assertEquals(ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED, result.mode, 'High risk scores require approval');
        System.assertEquals(true, result.requiresApproval, 'Approval is required');
    }

    @IsTest
    static void testEvaluateAction_Autonomous() {
        Test.startTest();
        ZentomPolicyEngine.PolicyEvaluation result = ZentomPolicyEngine.evaluateAction('Sync Record', 10.0, 'Sales');
        Test.stopTest();
        
        System.assertEquals(ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION, result.mode, 'Safe actions should execute autonomously');
        System.assertEquals(false, result.requiresApproval, 'Approval is not required');
    }
}

