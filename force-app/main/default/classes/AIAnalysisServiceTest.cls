/**
 * AIAnalysisServiceTest
 * Unit tests for AIAnalysisService root cause engine.
 *
 * @author   Tomcodex
 */
@IsTest
private class AIAnalysisServiceTest {

    // ── Helpers ────────────────────────────────────────────────────────────────
    private static Environment__c makeEnv() {
        Environment__c env = new Environment__c(Name = 'Production');
        insert env;
        return env;
    }

    private static SLA_Policy__c makePolicy(String severity) {
        SLA_Policy__c p = new SLA_Policy__c(
            Severity__c            = severity,
            Response_Time_Min__c   = 15,
            Resolution_Time_Min__c = 60
        );
        insert p;
        return p;
    }

    private static Integration_Log__c makeLog(String status, String error, Decimal resp) {
        Integration_Log__c log = new Integration_Log__c(
            API_Name__c      = 'Test API',
            Status__c        = status,
            Error_Message__c = error,
            Response_Time__c = resp
        );
        insert log;
        return log;
    }

    private static Incident__c makeIncident(Integration_Log__c log, Environment__c env) {
        Incident__c inc = new Incident__c(
            Severity__c         = 'Critical',
            Status__c           = 'New',
            Description__c      = 'Test incident',
            Integration_Log__c  = log.Id,
            Environment__c      = env.Id
        );
        insert inc;
        return inc;
    }

    // ── Tests ──────────────────────────────────────────────────────────────────

    @IsTest
    static void testConnectionPoolPattern() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = 'Connection pool exhausted';
        inp.responseTime      = 8000;
        inp.pastIncidentCount = 0;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Restart Service', result.recommendedAction, 'Expected Restart for pool exhaustion');
        System.assertEquals('High',            result.impactLevel,       'Expected High impact');
        System.assert(result.confidence >= 75,                           'Expected high confidence');
    }

    @IsTest
    static void testTimeoutWithLowHistory() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = 'Request timed out after 30s';
        inp.responseTime      = 30000;
        inp.pastIncidentCount = 1;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Restart Service', result.recommendedAction, 'Expected Restart Service for isolated timeout');
    }

    @IsTest
    static void testTimeoutWithHighHistory() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = 'Request timed out';
        inp.responseTime      = 6000;
        inp.pastIncidentCount = 10;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Restart Service', result.recommendedAction, 'Expected Restart Service for repeated timeout');
    }

    @IsTest
    static void testSchemaPattern() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = 'Schema mismatch — field Order_Priority__c missing';
        inp.responseTime      = 200;
        inp.pastIncidentCount = 0;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Escalate', result.recommendedAction, 'Expected Escalate for schema error');
    }

    @IsTest
    static void testAuthPattern() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = '401 Unauthorized — token expired';
        inp.responseTime      = 100;
        inp.pastIncidentCount = 0;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Escalate', result.recommendedAction, 'Expected Escalate for auth failure');
    }

    @IsTest
    static void testUnknownPatternEscalates() {
        AIAnalysisService.AnalysisInput inp = new AIAnalysisService.AnalysisInput();
        inp.errorMessage      = 'Unexpected internal error code XYZ-999';
        inp.responseTime      = 150;
        inp.pastIncidentCount = 0;

        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyse(inp);

        System.assertEquals('Escalate', result.recommendedAction, 'Unknown errors should escalate');
    }

    @IsTest
    static void testAnalyseIncidentById() {
        Environment__c env = makeEnv();
        Integration_Log__c log = makeLog('Failed', 'Connection pool exhausted', 8000);
        Incident__c inc = makeIncident(log, env);

        Test.startTest();
        AIAnalysisService.AnalysisResult result = AIAnalysisService.analyseIncident(inc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,                    'Result should not be null');
        System.assertNotEquals(null, result.rootCause,          'Root cause should be populated');
        System.assertNotEquals(null, result.recommendedAction,  'Action should be populated');

        Incident__c updated = [SELECT Root_Cause__c, Recommended_Action__c FROM Incident__c WHERE Id = :inc.Id];
        System.assertNotEquals(null, updated.Root_Cause__c, 'Root cause should be persisted on the incident');
    }

    @IsTest
    static void testAnalyseIncidentNullIdThrows() {
        Boolean threw = false;
        try {
            AIAnalysisService.analyseIncident(null);
        } catch (AIAnalysisService.AIAnalysisException e) {
            threw = true;
        }
        System.assert(threw, 'Expected AIAnalysisException for null Id');
    }
}
