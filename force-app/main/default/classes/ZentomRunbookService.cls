public with sharing class ZentomRunbookService {
    public static RunbookResult resolve(String runbookKey, String incidentType) {
        List<Zentom_Runbook__mdt> runbooks = new List<Zentom_Runbook__mdt>();

        if (!String.isBlank(runbookKey)) {
            runbooks = [
                SELECT Runbook_Key__c, Incident_Type__c, Title__c, Description__c,
                    Default_Action__c, Requires_Approval__c, Risk_Level__c, Is_Active__c,
                    Step_1__c, Step_2__c, Step_3__c, Step_4__c, Step_5__c
                FROM Zentom_Runbook__mdt
                WHERE Is_Active__c = true
                    AND Runbook_Key__c = :runbookKey
                LIMIT 1
            ];
        }

        if (runbooks.isEmpty() && !String.isBlank(incidentType)) {
            runbooks = [
                SELECT Runbook_Key__c, Incident_Type__c, Title__c, Description__c,
                    Default_Action__c, Requires_Approval__c, Risk_Level__c, Is_Active__c,
                    Step_1__c, Step_2__c, Step_3__c, Step_4__c, Step_5__c
                FROM Zentom_Runbook__mdt
                WHERE Is_Active__c = true
                    AND Incident_Type__c = :incidentType
                LIMIT 1
            ];
        }

        return runbooks.isEmpty() ? null : fromMetadata(runbooks[0]);
    }

    private static RunbookResult fromMetadata(Zentom_Runbook__mdt runbook) {
        RunbookResult result = new RunbookResult();
        result.runbookKey = runbook.Runbook_Key__c;
        result.incidentType = runbook.Incident_Type__c;
        result.title = runbook.Title__c;
        result.description = runbook.Description__c;
        result.defaultAction = runbook.Default_Action__c;
        result.requiresApproval = runbook.Requires_Approval__c;
        result.riskLevel = runbook.Risk_Level__c;
        result.steps = formatSteps(runbook);
        return result;
    }

    private static String formatSteps(Zentom_Runbook__mdt runbook) {
        List<String> steps = new List<String>();
        addStep(steps, 1, runbook.Step_1__c);
        addStep(steps, 2, runbook.Step_2__c);
        addStep(steps, 3, runbook.Step_3__c);
        addStep(steps, 4, runbook.Step_4__c);
        addStep(steps, 5, runbook.Step_5__c);
        return String.join(steps, '\n');
    }

    private static void addStep(List<String> steps, Integer index, String value) {
        if (!String.isBlank(value)) {
            steps.add(String.valueOf(index) + '. ' + value);
        }
    }

    public class RunbookResult {
        public String runbookKey;
        public String incidentType;
        public String title;
        public String description;
        public String defaultAction;
        public Boolean requiresApproval;
        public String riskLevel;
        public String steps;
    }
}