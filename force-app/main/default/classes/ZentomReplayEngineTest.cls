/**
 * ZentomReplayEngineTest
 * Validates the audit logging and Zentom_Replay_Log__c persistence.
 */
@IsTest
private class ZentomReplayEngineTest {

    @TestSetup
    static void setup() {
        Incident__c inc = new Incident__c(
            Severity__c = 'High',
            Description__c = 'OAuth token expired for payment gateway',
            Status__c = 'New'
        );
        insert inc;
    }

    @IsTest
    static void testLogDecision_CreatesReplayRecord() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        // Build mock engine outputs
        ZentomContextEngine.ContextPacket context = new ZentomContextEngine.ContextPacket();
        context.accountARR = 75000;
        context.accountTier = 'Growth';
        context.similarIncidents = new List<String>{'Test match'};

        ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
        risk.totalScore = 55.0;
        risk.technicalSeverity = 20;
        risk.businessImpact = 10;
        risk.blastRadius = 15;
        risk.operationalContext = 10;

        ZentomPolicyEngine.PolicyEvaluation policy = new ZentomPolicyEngine.PolicyEvaluation();
        policy.mode = ZentomPolicyEngine.ExecutionMode.AUTONOMOUS_EXECUTION;
        policy.policyReasoning = 'All gates passed.';
        policy.requiresApproval = false;

        Test.startTest();
        ZentomReplayEngine.logDecision(
            inc.Id, context, 'Test prompt', '{"test":"response"}',
            risk, policy, 'Restart Service', 92
        );
        Test.stopTest();

        List<Zentom_Replay_Log__c> logs = [SELECT Id, Risk_Score__c, Confidence_Score__c, Policy_Mode__c, Proposed_Action__c FROM Zentom_Replay_Log__c];
        System.assertEquals(1, logs.size(), 'One replay log should be created');
        System.assertEquals(55.0, logs[0].Risk_Score__c, 'Risk score should match');
        System.assertEquals(92, logs[0].Confidence_Score__c, 'Confidence should match');
        System.assertEquals('AUTONOMOUS_EXECUTION', logs[0].Policy_Mode__c, 'Policy mode should match');
        System.assertEquals('Restart Service', logs[0].Proposed_Action__c, 'Action should match');
    }

    @IsTest
    static void testLogDecision_EscalatedPolicy() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        ZentomContextEngine.ContextPacket context = new ZentomContextEngine.ContextPacket();
        context.accountARR = 200000;
        context.accountTier = 'Enterprise';
        context.similarIncidents = new List<String>();

        ZentomRiskEngine.RiskScore risk = new ZentomRiskEngine.RiskScore();
        risk.totalScore = 85.0;

        ZentomPolicyEngine.PolicyEvaluation policy = new ZentomPolicyEngine.PolicyEvaluation();
        policy.mode = ZentomPolicyEngine.ExecutionMode.HUMAN_APPROVAL_REQUIRED;
        policy.policyReasoning = 'Revenue risk exceeds $50k.';

        Test.startTest();
        ZentomReplayEngine.logDecision(inc.Id, context, 'Prompt', 'Response', risk, policy, 'Escalate', 65);
        Test.stopTest();

        List<Zentom_Replay_Log__c> logs = [SELECT Policy_Mode__c FROM Zentom_Replay_Log__c];
        System.assertEquals('HUMAN_APPROVAL_REQUIRED', logs[0].Policy_Mode__c, 'Escalated mode should be logged');
    }
}

