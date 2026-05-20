/**
 * @description Revenue Workflow Mapper — Phase 3 Core Module.
 * Maps the end-to-end revenue workflow chain:
 * Lead → Opportunity → Quote → Payment → ERP → Fulfillment
 * Identifies bottlenecks, broken links, and revenue-at-risk nodes.
 *
 * @group Revenue
 */
public with sharing class RevenueWorkflowMapper {

    public class WorkflowChain {
        @AuraEnabled public List<WorkflowNode> nodes { get; set; }
        @AuraEnabled public List<WorkflowLink> links { get; set; }
        @AuraEnabled public Decimal totalRevenueAtRisk { get; set; }
        @AuraEnabled public Integer brokenLinks { get; set; }
        @AuraEnabled public Integer activeThreats { get; set; }
        @AuraEnabled public String overallHealth { get; set; }
        @AuraEnabled public Datetime mappedAt { get; set; }
    }

    public class WorkflowNode {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String stage { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer recordCount { get; set; }
        @AuraEnabled public Decimal revenueValue { get; set; }
        @AuraEnabled public Integer incidentCount { get; set; }
        @AuraEnabled public String connectorName { get; set; }
        @AuraEnabled public Boolean hasActiveIncident { get; set; }
    }

    public class WorkflowLink {
        @AuraEnabled public String sourceId { get; set; }
        @AuraEnabled public String targetId { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal throughput { get; set; }
        @AuraEnabled public String latency { get; set; }
    }

    private static final List<String> STAGE_ORDER = new List<String>{
        'lead_capture', 'crm_sync', 'opportunity', 'quote',
        'payment', 'erp_sync', 'fulfillment', 'renewal'
    };

    /**
     * @description Builds a complete revenue workflow chain map with real-time health.
     */
    @AuraEnabled(cacheable=true)
    public static WorkflowChain buildWorkflowChain() {
        WorkflowChain chain = new WorkflowChain();
        chain.nodes = new List<WorkflowNode>();
        chain.links = new List<WorkflowLink>();
        chain.mappedAt = Datetime.now();

        // Gather connector health data
        Map<String, Integration_Endpoint__c> endpointsByName = new Map<String, Integration_Endpoint__c>();
        for (Integration_Endpoint__c ep : [
            SELECT Id, Name, Active__c, Circuit_Status__c, Failure_Count__c
            FROM Integration_Endpoint__c
            WITH USER_MODE
        ]) {
            endpointsByName.put(ep.Name.toLowerCase(), ep);
        }

        // Gather active incidents by integration
        Map<Id, Integer> incidentsByEndpoint = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Integration_Endpoint__c epId, COUNT(Id) cnt
            FROM Incident__c
            WHERE Status__c NOT IN ('Resolved', 'Closed')
            AND Integration_Endpoint__c != null
            GROUP BY Integration_Endpoint__c
        ]) {
            incidentsByEndpoint.put((Id) ar.get('epId'), (Integer) ar.get('cnt'));
        }

        // Gather revenue risk
        Map<String, Decimal> riskByLevel = new Map<String, Decimal>();
        Decimal totalRisk = 0;
        for (AggregateResult ar : [
            SELECT Risk_Level__c lvl, SUM(Risk_Amount__c) amt
            FROM Revenue_Risk__c
            WHERE Status__c = 'Open'
            GROUP BY Risk_Level__c
        ]) {
            String lvl = (String) ar.get('lvl');
            Decimal amt = (Decimal) ar.get('amt');
            riskByLevel.put(lvl, amt);
            totalRisk += amt != null ? amt : 0;
        }

        chain.totalRevenueAtRisk = totalRisk;

        // --- Build Nodes ---
        chain.nodes.add(buildNode('lead_capture', 'Lead Capture', 'Website / Forms', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('crm_sync', 'CRM Sync', 'Salesforce / HubSpot', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('opportunity', 'Opportunity Pipeline', 'Salesforce CRM', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('quote', 'Quote Generation', 'CPQ / Manual', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('payment', 'Payment Processing', 'Stripe / Razorpay', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('erp_sync', 'ERP Sync', 'SAP / NetSuite', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('fulfillment', 'Fulfillment', 'Shopify / Warehouse', endpointsByName, incidentsByEndpoint));
        chain.nodes.add(buildNode('renewal', 'Renewal & Retention', 'Subscription Service', endpointsByName, incidentsByEndpoint));

        // --- Build Links ---
        Integer brokenCount = 0;
        for (Integer i = 0; i < chain.nodes.size() - 1; i++) {
            WorkflowNode source = chain.nodes[i];
            WorkflowNode target = chain.nodes[i + 1];
            WorkflowLink link = new WorkflowLink();
            link.sourceId = source.id;
            link.targetId = target.id;

            if (source.hasActiveIncident || target.hasActiveIncident) {
                link.status = 'broken';
                brokenCount++;
            } else if (source.status == 'degraded' || target.status == 'degraded') {
                link.status = 'degraded';
            } else {
                link.status = 'healthy';
            }
            link.throughput = 100 - (source.incidentCount * 10);
            link.latency = source.hasActiveIncident ? 'High' : 'Normal';
            chain.links.add(link);
        }

        chain.brokenLinks = brokenCount;
        chain.activeThreats = 0;
        for (WorkflowNode n : chain.nodes) {
            chain.activeThreats += n.incidentCount;
        }
        chain.overallHealth = brokenCount == 0 ? 'Healthy' : (brokenCount <= 2 ? 'Degraded' : 'Critical');

        return chain;
    }

    /**
     * @description Gets revenue exposure breakdown by workflow stage.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getStageExposure() {
        List<Map<String, Object>> stages = new List<Map<String, Object>>();

        // Lead stage
        Integer leadCount = [SELECT COUNT() FROM Lead WHERE IsConverted = false AND Status != 'Disqualified'];
        stages.add(makeStageMap('Lead Capture', leadCount, 0, 'lead'));

        // Opportunity stage
        List<AggregateResult> oppData = [
            SELECT COUNT(Id) cnt, SUM(Amount) amt
            FROM Opportunity WHERE IsClosed = false
        ];
        Integer oppCount = oppData.isEmpty() ? 0 : (Integer) oppData[0].get('cnt');
        Decimal oppAmount = oppData.isEmpty() || oppData[0].get('amt') == null ? 0 : (Decimal) oppData[0].get('amt');
        stages.add(makeStageMap('Pipeline', oppCount, oppAmount, 'opportunity'));

        // Active incidents blocking revenue
        List<AggregateResult> incData = [
            SELECT COUNT(Id) cnt, SUM(Revenue_at_Risk__c) risk
            FROM Incident__c WHERE Status__c NOT IN ('Resolved', 'Closed')
        ];
        Integer incCount = incData.isEmpty() ? 0 : (Integer) incData[0].get('cnt');
        Decimal incRisk = incData.isEmpty() || incData[0].get('risk') == null ? 0 : (Decimal) incData[0].get('risk');
        stages.add(makeStageMap('Incidents Blocking', incCount, incRisk, 'incident'));

        // Revenue risks
        List<AggregateResult> rrData = [
            SELECT COUNT(Id) cnt, SUM(Risk_Amount__c) amt
            FROM Revenue_Risk__c WHERE Status__c = 'Open'
        ];
        Integer rrCount = rrData.isEmpty() ? 0 : (Integer) rrData[0].get('cnt');
        Decimal rrAmount = rrData.isEmpty() || rrData[0].get('amt') == null ? 0 : (Decimal) rrData[0].get('amt');
        stages.add(makeStageMap('Revenue at Risk', rrCount, rrAmount, 'risk'));

        return stages;
    }

    // ─── Helpers ───

    private static WorkflowNode buildNode(
        String id, String label, String connector,
        Map<String, Integration_Endpoint__c> endpoints,
        Map<Id, Integer> incidentsByEndpoint
    ) {
        WorkflowNode node = new WorkflowNode();
        node.id = id;
        node.stage = id;
        node.label = label;
        node.connectorName = connector;
        node.recordCount = 0;
        node.revenueValue = 0;
        node.incidentCount = 0;
        node.hasActiveIncident = false;

        // Try to match with an integration endpoint
        String connLower = connector.toLowerCase();
        for (String epName : endpoints.keySet()) {
            if (connLower.contains(epName) || epName.contains(connLower.split(' / ')[0].trim())) {
                Integration_Endpoint__c ep = endpoints.get(epName);
                if (ep.Circuit_Status__c == 'Open') {
                    node.status = 'broken';
                    node.hasActiveIncident = true;
                } else if (ep.Failure_Count__c > 0) {
                    node.status = 'degraded';
                }
                Integer epIncidents = incidentsByEndpoint.get(ep.Id);
                if (epIncidents != null) {
                    node.incidentCount = epIncidents;
                    node.hasActiveIncident = true;
                }
                break;
            }
        }

        if (node.status == null) {
            node.status = 'healthy';
        }

        return node;
    }

    private static Map<String, Object> makeStageMap(String name, Integer count, Decimal amount, String type) {
        return new Map<String, Object>{
            'name' => name,
            'count' => count,
            'amount' => amount,
            'type' => type
        };
    }
}

