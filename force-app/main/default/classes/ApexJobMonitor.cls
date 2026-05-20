public with sharing class ApexJobMonitor implements Schedulable {
    
    public void execute(SchedulableContext context) {
        monitorFailedJobs();
    }
    
    @future
    public static void monitorFailedJobs() {
        // Security Gate check
        SecurityGate.requireReadAccess('AsyncApexJob', new Set<String>{'Id', 'ApexClassId', 'JobType', 'Status', 'ExtendedStatus', 'CreatedDate'});
        SecurityGate.requireCreateable('Incident__c');

        // Query failed jobs from the last 24 hours
        List<AsyncApexJob> failedJobs = [
            SELECT Id, ApexClassId, ApexClass.Name, JobType, Status, ExtendedStatus, CreatedDate
            FROM AsyncApexJob
            WHERE Status IN ('Failed', 'Aborted') 
            AND CreatedDate >= YESTERDAY
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        if (failedJobs.isEmpty()) {
            return;
        }

        List<Incident__c> incidentsToCreate = new List<Incident__c>();
        
        for (AsyncApexJob job : failedJobs) {
            String className = job.ApexClass != null ? job.ApexClass.Name : 'Unknown Class';
            
            Incident__c inc = new Incident__c();
            inc.Severity__c = 'High';
            inc.Status__c = 'Open';
            inc.Error_Type__c = 'Apex Exception';
            inc.Description__c = 'The ' + job.JobType + ' job for ' + className + ' failed with status: ' + job.Status + '.\nDetails: ' + job.ExtendedStatus;
            
            incidentsToCreate.add(inc);
        }

        if (!incidentsToCreate.isEmpty()) {
            insert as user incidentsToCreate;
            AuditTrailService.log('ApexJobMonitor', 'System', 'Created', null, String.valueOf(incidentsToCreate.size()) + ' new Apex incidents detected.');
        }
    }
}

