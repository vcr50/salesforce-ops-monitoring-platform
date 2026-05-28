public with sharing class SentinelDataSeeder {
    public static void seedData() {
        List<Sentinel_Incident__c> incidents = new List<Sentinel_Incident__c>();
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'Payment Gateway Timeout',
            Environment__c = 'production',
            Risk_Level__c = 'Critical',
            Status__c = 'Approval Required',
            Runbook_Title__c = 'RB-PAY-007 - Restart Payment Service',
            Recommended_Action__c = 'Restart payment service, scale DB connections, and clear stuck jobs.',
            Runbook_Key__c = 'RB-PAY-007',
            AI_Summary__c = 'Multiple payment transactions are timing out and need operator review.'
        ));
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'High CPU Utilization',
            Environment__c = 'production',
            Risk_Level__c = 'Medium',
            Status__c = 'Approval Required',
            Runbook_Title__c = 'Scale APP-SVC-02',
            Recommended_Action__c = 'Scale up application instances by 2.',
            AI_Summary__c = 'CPU usage spiked to 98% across 4 instances.'
        ));
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'Redis Memory Warning',
            Environment__c = 'sandbox',
            Risk_Level__c = 'Low',
            Status__c = 'Approval Required',
            Runbook_Title__c = 'RB-CACHE-003 - Clear Redis Cache',
            Recommended_Action__c = 'Flush expired keys from staging cache.',
            AI_Summary__c = 'Cache hit ratio dropped below threshold.'
        ));
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'API Rate Limit',
            Environment__c = 'production',
            Risk_Level__c = 'Medium',
            Status__c = 'Analyzed',
            Runbook_Title__c = 'API Rate Limit Runbook'
        ));
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'Workflow Failure',
            Environment__c = 'production',
            Risk_Level__c = 'Low',
            Status__c = 'Closed',
            Runbook_Title__c = 'Workflow Failure Runbook'
        ));
        
        incidents.add(new Sentinel_Incident__c(
            Incident_Type__c = 'Login Anomaly',
            Environment__c = 'sandbox',
            Risk_Level__c = 'High',
            Status__c = 'Closed',
            Runbook_Title__c = 'Login Anomaly Runbook'
        ));
        
        insert incidents;
    }
}
