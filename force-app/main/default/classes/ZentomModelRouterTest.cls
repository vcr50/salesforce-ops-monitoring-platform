/**
 * ZentomModelRouterTest
 * Validates the AI model routing logic across all four model types.
 */
@IsTest
private class ZentomModelRouterTest {

    private static ZentomContextEngine.ContextPacket buildContext(Decimal arr) {
        ZentomContextEngine.ContextPacket ctx = new ZentomContextEngine.ContextPacket();
        ctx.accountARR = arr;
        ctx.accountTier = arr >= 100000 ? 'Enterprise' : 'Standard';
        ctx.similarIncidents = new List<String>();
        return ctx;
    }

    private static ZentomRiskEngine.RiskScore buildRisk(Decimal total) {
        ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
        risk.totalScore = total;
        risk.technicalSeverity = 20;
        risk.businessImpact = 10;
        risk.blastRadius = 10;
        risk.operationalContext = 10;
        return risk;
    }

    @IsTest
    static void testRoute_CodeAnalysis_ReturnsDeepSeekCoder() {
        Test.startTest();
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(buildContext(10000), buildRisk(30), 'CODE_ANALYSIS');
        Test.stopTest();

        System.assertEquals(ZentomModelRouter.AIModel.DEEPSEEK_CODER, model, 'Code tasks should route to DeepSeek Coder');
    }

    @IsTest
    static void testRoute_SalesforceUpdate_ReturnsAgentforce() {
        Test.startTest();
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(buildContext(10000), buildRisk(30), 'SALESFORCE_RECORD_UPDATE');
        Test.stopTest();

        System.assertEquals(ZentomModelRouter.AIModel.AGENTFORCE, model, 'Record updates should route to Agentforce');
    }

    @IsTest
    static void testRoute_HighRisk_ReturnsDeepSeekR1() {
        Test.startTest();
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(buildContext(10000), buildRisk(85), 'SYSTEM_FAILURE');
        Test.stopTest();

        System.assertEquals(ZentomModelRouter.AIModel.DEEPSEEK_R1, model, 'High risk should route to DeepSeek R1');
    }

    @IsTest
    static void testRoute_HighARR_ReturnsDeepSeekR1() {
        Test.startTest();
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(buildContext(200000), buildRisk(30), 'SYSTEM_FAILURE');
        Test.stopTest();

        System.assertEquals(ZentomModelRouter.AIModel.DEEPSEEK_R1, model, 'High ARR accounts should route to DeepSeek R1');
    }

    @IsTest
    static void testRoute_LowRiskLowARR_ReturnsLlama3() {
        Test.startTest();
        ZentomModelRouter.AIModel model = ZentomModelRouter.route(buildContext(5000), buildRisk(30), 'SYSTEM_FAILURE');
        Test.stopTest();

        System.assertEquals(ZentomModelRouter.AIModel.LLAMA_3, model, 'Low risk + low ARR should default to Llama 3');
    }
}

