public with sharing class RevenuePulseService {
    
    /**
     * @description Analyzes all open incidents, invokes the BusinessImpactCalculator, 
     * and synchronizes the financial risk data to Revenue_Risk__c records.
     * This acts as the core engine for the "Revenue Pulse" dashboard.
     */
    @AuraEnabled
    public static void executePulseSync() {
        // 1. Trigger the calculation for all open incidents
        // This calculates the Users Affected x ARPU and updates the Incident__c records.
        BusinessImpactCalculator.calculateAllOpen();
        
        // 2. Query the updated Incidents
        SecurityGate.requireReadAccess('Incident__c', new Set<String>{
            'Id', 'Revenue_at_Risk__c', 'AI_Impact_Level__c'
        });
        List<Incident__c> openIncidents = [
            SELECT Id, Revenue_at_Risk__c, AI_Impact_Level__c 
            FROM Incident__c 
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            WITH USER_MODE
        ];
        
        if (openIncidents.isEmpty()) {
            return; // Nothing to sync
        }

        // 3. Find existing Revenue_Risk__c records to avoid duplicates
        SecurityGate.requireReadAccess('Revenue_Risk__c', new Set<String>{
            'Id', 'Related_Incident__c', 'Status__c'
        });
        Map<Id, Revenue_Risk__c> existingRisks = new Map<Id, Revenue_Risk__c>();
        for (Revenue_Risk__c risk : [
            SELECT Id, Related_Incident__c 
            FROM Revenue_Risk__c 
            WHERE Status__c = 'Open' AND Related_Incident__c IN :openIncidents
            WITH USER_MODE
        ]) {
            existingRisks.put(risk.Related_Incident__c, risk);
        }
        
        // 4. Prepare Upsert List
        List<Revenue_Risk__c> risksToUpsert = new List<Revenue_Risk__c>();
        
        for (Incident__c inc : openIncidents) {
            Revenue_Risk__c riskRecord = existingRisks.containsKey(inc.Id) 
                ? existingRisks.get(inc.Id) 
                : new Revenue_Risk__c(Related_Incident__c = inc.Id, Status__c = 'Open');
                
            riskRecord.Risk_Amount__c = inc.Revenue_at_Risk__c != null ? inc.Revenue_at_Risk__c : 0;
            riskRecord.Risk_Level__c = inc.AI_Impact_Level__c != null ? inc.AI_Impact_Level__c : 'Low';
            
            // Assume the affected pipeline is 1.5x the direct revenue risk 
            // (e.g. potential future loss due to churn)
            riskRecord.Affected_Pipeline__c = riskRecord.Risk_Amount__c * 1.5; 
            
            risksToUpsert.add(riskRecord);
        }
        
        // 5. Commit to Database
        if (!risksToUpsert.isEmpty()) {
            SecurityGate.requireCreateAccess('Revenue_Risk__c', new Set<String>{
                'Related_Incident__c', 'Status__c', 'Risk_Amount__c', 'Risk_Level__c', 'Affected_Pipeline__c'
            });
            SecurityGate.requireUpdateAccess('Revenue_Risk__c', new Set<String>{
                'Risk_Amount__c', 'Risk_Level__c', 'Affected_Pipeline__c'
            });
            upsert as user risksToUpsert;
        }
        
        // 6. Log the execution
        System.debug('RevenuePulseService: Synchronized ' + risksToUpsert.size() + ' Revenue Risk records.');
    }

    // --- UI DTOs ---

    public class RiskActionDTO {
        @AuraEnabled public Id riskId;
        @AuraEnabled public Id incidentId;
        @AuraEnabled public String incidentName;
        @AuraEnabled public String businessImpact;
        @AuraEnabled public String recommendedAction;
        @AuraEnabled public String riskLevel;
    }

    public class RiskSummaryDTO {
        @AuraEnabled public Decimal totalRiskAmount = 0;
        @AuraEnabled public Integer criticalIncidentsCount = 0;
        @AuraEnabled public Integer highIncidentsCount = 0;
        @AuraEnabled public Integer openRisksCount = 0;
        @AuraEnabled public List<RiskActionDTO> topActions = new List<RiskActionDTO>();
    }

    /**
     * @description Returns the aggregated Revenue Risk data for the LWC Dashboard.
     */
    @AuraEnabled(cacheable=true)
    public static RiskSummaryDTO getOrgRiskSummary() {
        RiskSummaryDTO summary = new RiskSummaryDTO();
        
        SecurityGate.requireReadAccess('Revenue_Risk__c', new Set<String>{
            'Id', 'Status__c', 'Risk_Amount__c', 'Risk_Level__c', 'Related_Incident__c'
        });
        
        List<Revenue_Risk__c> openRisks = [
            SELECT Id, Risk_Amount__c, Risk_Level__c,
                   Related_Incident__c, Related_Incident__r.Name, 
                   Related_Incident__r.Description__c,
                   Related_Incident__r.Recommended_Action__c
            FROM Revenue_Risk__c 
            WHERE Status__c = 'Open'
            WITH USER_MODE
            ORDER BY Risk_Amount__c DESC
        ];

        summary.openRisksCount = openRisks.size();

        for (Revenue_Risk__c risk : openRisks) {
            summary.totalRiskAmount += (risk.Risk_Amount__c != null ? risk.Risk_Amount__c : 0);
            
            if (risk.Risk_Level__c == 'Critical') {
                summary.criticalIncidentsCount++;
            } else if (risk.Risk_Level__c == 'High') {
                summary.highIncidentsCount++;
            }

            // Populate top 5 actions
            if (summary.topActions.size() < 5) {
                RiskActionDTO action = new RiskActionDTO();
                action.riskId = risk.Id;
                action.incidentId = risk.Related_Incident__c;
                action.incidentName = risk.Related_Incident__r.Name;
                action.riskLevel = risk.Risk_Level__c;
                action.recommendedAction = risk.Related_Incident__r.Recommended_Action__c;
                
                String descr = risk.Related_Incident__r.Description__c;
                if (descr != null && descr.length() > 60) {
                    descr = descr.substring(0, 60) + '...';
                }
                action.businessImpact = descr;
                
                summary.topActions.add(action);
            }
        }

        return summary;
    }
}

