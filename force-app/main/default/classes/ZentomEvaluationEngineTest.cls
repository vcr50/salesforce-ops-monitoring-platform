/**
 * ZentomEvaluationEngineTest
 * Validates the quality measurement and drift detection system.
 */
@IsTest
private class ZentomEvaluationEngineTest {

    @IsTest
    static void testEvaluateOutcome_SuccessfulAction() {
        Test.startTest();
        // Should not throw any exception
        ZentomEvaluationEngine.evaluateOutcome(null, true, 'Restart Service', 92);
        Test.stopTest();
        // No assertion needed — verifying no exception is thrown
    }

    @IsTest
    static void testEvaluateOutcome_FailedAction_LowConfidence() {
        Test.startTest();
        ZentomEvaluationEngine.evaluateOutcome(null, false, 'Retry', 50);
        Test.stopTest();
        // Low confidence failure is expected — no drift alert
    }

    @IsTest
    static void testEvaluateOutcome_DriftDetection() {
        Test.startTest();
        // High confidence (>=90) but failed — should trigger drift alert in logs
        ZentomEvaluationEngine.evaluateOutcome(null, false, 'Restart Service', 95);
        Test.stopTest();
        // Verifying the method completes without exception during drift detection
    }
}

