/**
 * BusinessGraphEngine
 * Phase 2 of the CTO Blueprint: The "Billion-Dollar Layer".
 *
 * This engine analyzes incoming Universal Events and maps them to actual
 * enterprise revenue operations (Leads, Opportunities, Accounts) to calculate
 * true pipeline exposure rather than just estimated ARPU.
 *
 * @author SentinelFlow
 * @version 1.0
 */
public inherited sharing class BusinessGraphEngine {

    /**
     * Enriches Universal Events with actual business impact context by connecting
     * external operational failures to Salesforce CRM revenue objects.
     */
    public static void enrichUniversalEvents(List<Universal_Event__c> events) {
        if (events == null || events.isEmpty()) return;

        Set<Id> tenantIds = new Set<Id>();
        for (Universal_Event__c ev : events) {
            if (ev.Tenant__c != null) {
                tenantIds.add(ev.Tenant__c);
            }
        }

        // Fast-path out if no tenant data to map against
        if (tenantIds.isEmpty()) return;

        // In a full enterprise environment, this would build a massive dependency graph.
        // For Phase 2 MVP, we will query at-risk open pipeline for the affected tenant
        // and link the operational failure to the highest-value active Opportunities.
        
        Map<Id, List<Opportunity>> openPipelineByTenant = getOpenPipeline(tenantIds);

        for (Universal_Event__c ev : events) {
            // Only process events that are failures and have some risk
            if (ev.Status__c == 'Resolved' || ev.Recovery_Possible__c == false && ev.Revenue_Risk__c == 0) {
                continue;
            }

            List<Opportunity> pipeline = openPipelineByTenant.get(ev.Tenant__c);
            
            if (pipeline != null && !pipeline.isEmpty()) {
                // Heuristic: If it's a payment/checkout issue, it directly impacts 
                // the highest value closing opportunities.
                if (ev.Workflow_Stage__c == 'Payment' || ev.Workflow_Stage__c == 'Fulfillment') {
                    Opportunity highestValueOpp = pipeline[0]; // Ordered by Amount DESC
                    
                    Decimal actualRisk = highestValueOpp.Amount != null ? highestValueOpp.Amount : ev.Revenue_Risk__c;
                    
                    ev.Revenue_Risk__c = actualRisk;
                    ev.Business_Impact__c = 'CRITICAL: Workflow failure threatens active pipeline. ' +
                                            'At-risk Opportunity: ' + highestValueOpp.Name + 
                                            ' ($' + actualRisk.setScale(0).toPlainString() + ')';
                } 
                // If it's a Lead Capture issue, it impacts the top of the funnel
                else if (ev.Workflow_Stage__c == 'Lead Capture') {
                    // Aggregate smaller deals or average deal size
                    Decimal pipelineAvg = 0;
                    for (Opportunity opp : pipeline) {
                        pipelineAvg += (opp.Amount != null ? opp.Amount : 0);
                    }
                    if (pipeline.size() > 0) {
                        pipelineAvg = pipelineAvg / pipeline.size();
                    }
                    
                    ev.Revenue_Risk__c = pipelineAvg;
                    ev.Business_Impact__c = 'Lead funnel degraded. Average pipeline loss exposure: $' + 
                                            pipelineAvg.setScale(0).toPlainString() + ' per failed capture.';
                }
            }
        }
    }

    /**
     * Retrieves the top 5 open, high-value opportunities for each tenant.
     * This acts as the "At Risk Pipeline" cache for the Business Graph.
     */
    private static Map<Id, List<Opportunity>> getOpenPipeline(Set<Id> tenantIds) {
        Map<Id, List<Opportunity>> result = new Map<Id, List<Opportunity>>();
        
        // Ensure FLS before querying Opportunity Amount
        if (!Schema.sObjectType.Opportunity.isAccessible()) {
            return result;
        }

        // We assume Tenant__c is a custom field on Opportunity if tenant isolation is full.
        // For standard Salesforce single-org setups, we just query open Opps.
        Boolean hasTenantField = Schema.sObjectType.Opportunity.fields.getMap().containsKey('Tenant__c');
        
        String query = 'SELECT Id, Name, Amount, StageName ';
        if (hasTenantField) {
            query += ', Tenant__c ';
        }
        query += 'FROM Opportunity WHERE IsClosed = false AND Amount > 0 ORDER BY Amount DESC LIMIT 50';

        List<Opportunity> opps = Database.query(query);

        for (Opportunity opp : opps) {
            Id tId = hasTenantField ? (Id)opp.get('Tenant__c') : null;
            
            // If single-tenant org, apply to all active tenants in the event batch
            if (!hasTenantField) {
                for (Id eventTenantId : tenantIds) {
                    if (!result.containsKey(eventTenantId)) {
                        result.put(eventTenantId, new List<Opportunity>());
                    }
                    result.get(eventTenantId).add(opp);
                }
            } else if (tId != null) {
                if (!result.containsKey(tId)) {
                    result.put(tId, new List<Opportunity>());
                }
                result.get(tId).add(opp);
            }
        }

        return result;
    }
}

