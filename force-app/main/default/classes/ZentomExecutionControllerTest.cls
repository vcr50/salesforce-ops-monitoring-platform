/**
 * ZentomExecutionControllerTest
 * Validates the final governance gate and dispatch logic.
 */
@IsTest
private class ZentomExecutionControllerTest {

    @IsTest
    static void testExecuteAction_BlockedByLowConfidence() {
        ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
        risk.totalScore = 30;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentomExecutionController.executeAction(
                null, 'Restart Service', 60, risk,
                ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Confidence too low'), 'Should mention low confidence');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Low confidence should throw AuraHandledException');
    }

    @IsTest
    static void testExecuteAction_BlockedByPolicy() {
        ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
        risk.totalScore = 30;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentomExecutionController.executeAction(
                null, 'Restart Service', 95, risk,
                ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Policy Mode'), 'Should mention policy block');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Non-autonomous policy should throw AuraHandledException');
    }
}

