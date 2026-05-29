public with sharing class FlowHealthMonitor implements Schedulable {
    
    @TestVisible
    private static List<SObject> mockFailedFlows;

    public void execute(SchedulableContext context) {
        monitorFailedFlows();
    }
    
    @future
    public static void monitorFailedFlows() {
        // Security Gate check
        SecurityGate.requireReadAccess('FlowInterviewLog', new Set<String>{'Id', 'FlowVersionId', 'Status', 'FlowInterviewId', 'CreatedDate'});
        SecurityGate.requireCreateAccess('Flow_Health__c', new Set<String>{
            'Flow_API_Name__c', 'Last_Run_Status__c', 'Last_Failure_Date__c', 'Error_Message__c'
        });
        SecurityGate.requireCreateAccess('Incident__c', new Set<String>{
            'Severity__c', 'Status__c', 'Error_Type__c', 'Description__c'
        });
        // Query failed Flow Interviews
        List<SObject> failedFlows = new List<SObject>();
        if (Test.isRunningTest() && mockFailedFlows != null) {
            failedFlows = mockFailedFlows;
        } else {
            try {
                failedFlows = Database.query('SELECT Id, FlowVersionId, FlowInterviewId, CreatedDate FROM FlowInterviewLog WHERE Status = \'Error\' AND CreatedDate >= YESTERDAY ORDER BY CreatedDate DESC LIMIT 50');
            } catch (Exception e) {
                System.debug('FlowInterviewLog not accessible: ' + e.getMessage());
                return;
            }
        }

        if (failedFlows.isEmpty()) {
            return;
        }

        List<Flow_Health__c> healthLogs = new List<Flow_Health__c>();
        List<Incident__c> incidents = new List<Incident__c>();
        
        for (SObject flowLog : failedFlows) {
            String flowId = 'Unknown';
            DateTime failureDate = System.now();
            try {
                flowId = (String) flowLog.get('FlowVersionId');
                failureDate = (DateTime) flowLog.get('CreatedDate');
            } catch (Exception e) {
                // Defensive — field may not exist on mock SObject type
            }
            
            Flow_Health__c health = new Flow_Health__c();
            health.Flow_API_Name__c = 'FlowVersion_' + flowId;
            health.Last_Run_Status__c = 'Failed';
            health.Last_Failure_Date__c = failureDate;
            health.Error_Message__c = 'Flow Execution Error Detected';
            healthLogs.add(health);
            
            Incident__c inc = new Incident__c();
            inc.Severity__c = 'Medium';
            inc.Status__c = 'Open';
            inc.Error_Type__c = 'Flow Exception';
            inc.Description__c = 'A critical Salesforce Flow failed to execute properly. Please review the Flow Interview Logs.';
            incidents.add(inc);
        }

        if (!healthLogs.isEmpty()) {
            insert as user healthLogs;
            insert as user incidents;
            AuditTrailService.log(null, 'FlowHealthMonitor', 'Created', null, String.valueOf(incidents.size()) + ' new Flow incidents detected.');
            UniversalEventNormalizer.normalizeFlowHealth(healthLogs);
        }
    }

    /**
     * Registers a single Flow failure manually or from a flow fault path.
     */
    public static void registerFlowFailure(String apiName, String flowLabel, String errorMsg, Integer affectedRecords) {
        // Enforce Security Gates
        SecurityGate.requireCreateAccess('Flow_Health__c', new Set<String>{
            'Flow_API_Name__c', 'Last_Run_Status__c', 'Failure_Count__c', 'Affected_Records__c', 'Error_Message__c', 'Last_Failure_Date__c'
        });
        SecurityGate.requireUpdateAccess('Flow_Health__c', new Set<String>{
            'Last_Run_Status__c', 'Failure_Count__c', 'Affected_Records__c', 'Error_Message__c', 'Last_Failure_Date__c'
        });
        SecurityGate.requireCreateAccess('Incident__c', new Set<String>{
            'Severity__c', 'Status__c', 'Error_Type__c', 'Description__c'
        });

        // 1. Get or create Flow_Health__c
        List<Flow_Health__c> existing = [
            SELECT Id, Failure_Count__c FROM Flow_Health__c 
            WHERE Flow_API_Name__c = :apiName 
            LIMIT 1
        ];
        Flow_Health__c health;
        if (!existing.isEmpty()) {
            health = existing[0];
            health.Failure_Count__c = (health.Failure_Count__c != null ? health.Failure_Count__c : 0) + 1;
        } else {
            health = new Flow_Health__c(
                Flow_API_Name__c = apiName,
                Failure_Count__c = 1
            );
        }
        health.Last_Run_Status__c = 'Failed';
        health.Affected_Records__c = affectedRecords;
        health.Error_Message__c = errorMsg;
        health.Last_Failure_Date__c = System.now();
        upsert as user health;

        // 2. Create Incident__c
        Incident__c inc = new Incident__c(
            Severity__c = 'Medium',
            Status__c = 'Open',
            Error_Type__c = 'Flow Exception',
            Description__c = 'Flow execution failure detected: ' + apiName + ' - ' + errorMsg
        );
        insert as user inc;

        AuditTrailService.log(inc.Id, 'FlowHealthMonitor', 'Created', null, 'Flow failure logged for ' + apiName);
    }
}