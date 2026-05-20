/**
 * AIAnalysisService
 * Agentforce-style AI analysis for incident root cause detection.
 * Driven entirely by AI_Rule__mdt Custom Metadata.
 *
 * @author   Tomcodex
 * @version  2.0
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class AIAnalysisService {

    public class AnalysisInput {
        public String  status;
        public String  errorMessage;
        public Decimal responseTime;
        public Integer pastIncidentCount;
        public Id      incidentId;
    }

    public class AnalysisResult {
        @AuraEnabled public String  rootCause;
        @AuraEnabled public String  recommendedAction;
        @AuraEnabled public String  impactLevel;
        @AuraEnabled public Decimal confidence;
        @AuraEnabled public String  explanation;
    }

    /**
     * Analyse a single incident using Custom Metadata AI Rules.
     */
    public static AnalysisResult analyse(AnalysisInput input) {
        if (input == null) {
            throw new AIAnalysisException('AnalysisInput must not be null.');
        }

        // -- Security Gate: Custom Metadata read check --
        SecurityGate.requireAccessible('AI_Rule__mdt');

        AnalysisResult result = new AnalysisResult();
        String errLower = String.isBlank(input.errorMessage) ? '' : input.errorMessage.toLowerCase();

        // ── AI Analysis (Zentom Orchestration Layer) ──────────────────────
        String userPrompt = 'Analyze the following incident and recommend an action. Error: ' + (String.isBlank(input.errorMessage) ? 'Unknown Error' : input.errorMessage);
        String additionalContext = 'Severity: Critical\nRevenue Risk: 0'; // In background, we fetch the real incident for Revenue Risk if possible
        
        if (input.incidentId != null) {
            try {
                Incident__c inc = [SELECT Severity__c, Revenue_at_Risk__c FROM Incident__c WHERE Id = :input.incidentId LIMIT 1];
                additionalContext = 'Severity: ' + inc.Severity__c + '\nRevenue Risk: ' + (inc.Revenue_at_Risk__c != null ? String.valueOf(inc.Revenue_at_Risk__c) : '0');
            } catch (Exception e) {}
        }
        
        ZentomAIClient.ZentomDecision decision = null;
        if (!Test.isRunningTest()) {
            try {
                decision = ZentomAIClient.getZentomResponse(userPrompt, additionalContext);
            } catch (Exception e) {
                System.debug('Zentom Callout failed: ' + e.getMessage());
            }
        }

        if (decision != null) {
            result.rootCause         = decision.recommendation + '\n\nRationale: ' + decision.rationale;
            result.recommendedAction = decision.proposed_action;
            result.impactLevel       = 'High';
            result.confidence        = decision.confidence_score;
            result.explanation       = 'Zentom Agentforce AI Analysis';
            return result;
        }

        // Query active Custom Metadata Rules
        List<AI_Rule__mdt> rules = [
            SELECT Keyword__c, Root_Cause__c, Recommendation__c, Confidence__c, Impact_Level__c
            FROM AI_Rule__mdt
        ];

        Boolean ruleMatched = false;

        for (AI_Rule__mdt rule : rules) {
            if (String.isNotBlank(rule.Keyword__c) && errLower.contains(rule.Keyword__c.toLowerCase())) {
                result.rootCause         = rule.Root_Cause__c;
                result.recommendedAction = rule.Recommendation__c;
                result.impactLevel       = rule.Impact_Level__c;
                result.confidence        = rule.Confidence__c;
                result.explanation       = 'Matched rule keyword: ' + rule.Keyword__c;
                ruleMatched              = true;
                break;
            }
        }

        // Fallback generic logic if no metadata rule matches
        if (!ruleMatched) {
            if (input.responseTime != null && input.responseTime >= 5000) {
                result.rootCause         = 'Severe response time degradation.';
                result.recommendedAction = 'Restart Service';
                result.impactLevel       = 'High';
                result.confidence        = 75.0;
                result.explanation       = 'Response time exceeded critical 5s threshold.';
            } else {
                result.rootCause         = 'Unknown error pattern — manual investigation required.';
                result.recommendedAction = 'Escalate';
                result.impactLevel       = 'Medium';
                result.confidence        = 50.0;
                result.explanation       = 'No matching custom metadata rule found.';
            }
        }

        return result;
    }

    /**
     * Analyse an incident record directly by Id.
     */
    @AuraEnabled
    public static AnalysisResult analyseIncident(Id incidentId) {
        if (incidentId == null) {
            throw new AIAnalysisException('Incident Id must not be null.');
        }

        // -- Security Gate: CRUD/FLS enforcement --
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Description__c', 'Status__c', 'Root_Cause__c',
            'Recommended_Action__c', 'AI_Impact_Level__c', 'AI_Confidence__c'
        });
        SecurityGate.requireUpdateAccess('Incident__c', new Set<String>{
            'Root_Cause__c', 'Recommended_Action__c', 'AI_Impact_Level__c', 'AI_Confidence__c'
        });

        Incident__c inc = [
            SELECT Id, Description__c, Status__c,
                   Integration_Log__r.Status__c,
                   Integration_Log__r.Error_Message__c,
                   Integration_Log__r.Response_Time__c
            FROM Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        AnalysisInput inp       = new AnalysisInput();
        inp.incidentId          = incidentId;
        inp.status              = inc.Integration_Log__r != null ? inc.Integration_Log__r.Status__c    : inc.Status__c;
        inp.errorMessage        = inc.Integration_Log__r != null ? inc.Integration_Log__r.Error_Message__c : inc.Description__c;
        inp.responseTime        = inc.Integration_Log__r != null ? inc.Integration_Log__r.Response_Time__c  : null;
        inp.pastIncidentCount   = 0;

        AnalysisResult result = analyse(inp);

        inc.Root_Cause__c         = result.rootCause;
        inc.Recommended_Action__c = result.recommendedAction;
        inc.AI_Impact_Level__c    = result.impactLevel;
        inc.AI_Confidence__c      = result.confidence;
        inc.Status__c             = 'Investigating';
        
        update inc;

        // -- Persist AI Decision audit trail --
        SecurityGate.requireCreateAccess('AI_Decision__c', new Set<String>{
            'Incident__c', 'Root_Cause__c', 'Recommended_Action__c',
            'Confidence_Score__c', 'Impact_Level__c', 'Auto_Executed__c',
            'Matched_Rule__c', 'Tenant__c'
        });
        AI_Decision__c decision = new AI_Decision__c(
            Incident__c           = incidentId,
            Root_Cause__c         = result.rootCause,
            Recommended_Action__c = result.recommendedAction,
            Confidence_Score__c   = result.confidence,
            Impact_Level__c       = result.impactLevel,
            Auto_Executed__c      = false,
            Matched_Rule__c       = result.explanation,
            Tenant__c             = TenantContext.getCurrentTenantId()
        );
        insert decision;

        AuditTrailService.log(incidentId, 'Incident__c', 'AI Analysis', null, 'Matched metadata rule -> Action: ' + result.recommendedAction);

        return result;
    }

    public class AIAnalysisException extends Exception {}
}

