/**
 * AIAnalysisService
 * Agentforce-style AI analysis for incident root cause detection.
 * Driven entirely by AI_Rule__mdt Custom Metadata.
 *
 * @author   Tomcodex
 * @version  2.0
 */
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

        AnalysisResult result = new AnalysisResult();
        String errLower = String.isBlank(input.errorMessage) ? '' : input.errorMessage.toLowerCase();

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
        
        update inc;

        AuditTrailService.log(incidentId, 'Incident__c', 'AI Analysis', null, 'Matched metadata rule -> Action: ' + result.recommendedAction);

        return result;
    }

    public class AIAnalysisException extends Exception {}
}
