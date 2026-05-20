/**
 * ZentomRiskEngineTest
 * Validates the four-dimensional risk scoring system.
 */
@IsTest
private class ZentomRiskEngineTest {

    @IsTest
    static void testEvaluateRisk_HighARR() {
        // Simulate a high-ARR context packet
        ZentomContextEngine.ContextPacket context = new ZentomContextEngine.ContextPacket();
        context.accountARR = 250000.00;
        context.accountTier = 'Enterprise';
        context.similarIncidents = new List<String>{'Test incident'};

        Test.startTest();
        ZentomRiskEngine.RiskScore score = ZentomRiskEngine.evaluateRisk(null, context);
        Test.stopTest();

        System.assertEquals(35.0, score.businessImpact, 'High ARR (>100k) should yield business impact of 35');
        System.assert(score.totalScore > 70, 'Total score should exceed 70 for high-ARR accounts');
    }

    @IsTest
    static void testEvaluateRisk_LowARR() {
        ZentomContextEngine.ContextPacket context = new ZentomContextEngine.ContextPacket();
        context.accountARR = 5000.00;
        context.accountTier = 'Standard';
        context.similarIncidents = new List<String>();

        Test.startTest();
        ZentomRiskEngine.RiskScore score = ZentomRiskEngine.evaluateRisk(null, context);
        Test.stopTest();

        System.assertEquals(10.0, score.businessImpact, 'Low ARR (<100k) should yield business impact of 10');
        System.assert(score.totalScore <= 70, 'Total score should be moderate for low-ARR accounts');
    }

    @IsTest
    static void testEvaluateRisk_AllDimensionsPopulated() {
        ZentomContextEngine.ContextPacket context = new ZentomContextEngine.ContextPacket();
        context.accountARR = 50000.00;
        context.similarIncidents = new List<String>();

        Test.startTest();
        ZentomRiskEngine.RiskScore score = ZentomRiskEngine.evaluateRisk(null, context);
        Test.stopTest();

        System.assertNotEquals(null, score.technicalSeverity, 'Technical severity should be set');
        System.assertNotEquals(null, score.businessImpact, 'Business impact should be set');
        System.assertNotEquals(null, score.blastRadius, 'Blast radius should be set');
        System.assertNotEquals(null, score.operationalContext, 'Operational context should be set');
        System.assertEquals(
            score.technicalSeverity + score.businessImpact + score.blastRadius + score.operationalContext,
            score.totalScore,
            'Total score should be the sum of all dimensions'
        );
    }
}

