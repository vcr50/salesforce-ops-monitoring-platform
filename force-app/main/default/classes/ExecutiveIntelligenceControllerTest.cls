/**
 * ExecutiveIntelligenceControllerTest
 * Tests the Phase 6 Executive Metrics calculations.
 *
 * @author SentinelFlow
 * @version 1.0
 */
@IsTest
private class ExecutiveIntelligenceControllerTest {

    @TestSetup
    static void setup() {
        // Create TenantContext dependency setup if needed, 
        // for standard test isolation we just mock data.
        
        List<Incident__c> incs = new List<Incident__c>();
        incs.add(new Incident__c(
            Status__c = 'New',
            Severity__c = 'Critical',
            Revenue_at_Risk__c = 150000
        ));
        incs.add(new Incident__c(
            Status__c = 'Escalated',
            Severity__c = 'High',
            Revenue_at_Risk__c = 50000
        ));
        incs.add(new Incident__c(
            Status__c = 'Resolved',
            Auto_Heal_Status__c = 'Succeeded',
            Severity__c = 'Medium',
            Revenue_at_Risk__c = 25000
        ));
        insert incs;

        List<Universal_Event__c> events = new List<Universal_Event__c>();
        events.add(new Universal_Event__c(
            Workflow_Stage__c = 'Payment',
            Revenue_Risk__c = 200000,
            Status__c = 'New'
        ));
        events.add(new Universal_Event__c(
            Workflow_Stage__c = 'Payment',
            Revenue_Risk__c = 50000,
            Status__c = 'New'
        ));
        events.add(new Universal_Event__c(
            Workflow_Stage__c = 'Fulfillment',
            Revenue_Risk__c = 30000,
            Status__c = 'New'
        ));
        insert events;
    }

    @IsTest
    static void testGetExecutiveMetrics() {
        Test.startTest();
        ExecutiveIntelligenceController.ExecutiveMetrics metrics = ExecutiveIntelligenceController.getExecutiveMetrics();
        Test.stopTest();

        // 1. Total Revenue at Risk (New + Escalated = 150k + 50k = 200k)
        System.assertEquals(200000, metrics.totalRevenueAtRisk, 'Revenue at Risk should sum open incidents.');

        // 2. Active Critical Incidents (1 Critical Incident)
        System.assertEquals(1, metrics.activeCriticalIncidents);

        // 3. AI Prevention Metrics (Resolved via Succeeded = 25k)
        System.assertEquals(25000, metrics.revenueSavedByAI);

        // 4. Business Safety Score Algorithm
        // 1 Critical (15 penalty) + 2 Open Incidents (4 penalty) = 19 penalty. Score = 81.
        System.assertEquals(81, metrics.businessSafetyScore);

        // 5. Workflow Risk Map
        System.assertEquals(2, metrics.topWorkflowRisks.size());
        
        // Payment should be top (250k)
        System.assertEquals('Payment', metrics.topWorkflowRisks[0].workflowStage);
        System.assertEquals(250000, metrics.topWorkflowRisks[0].aggregatedRisk);
        System.assertEquals(2, metrics.topWorkflowRisks[0].failureCount);
        
        // Fulfillment should be second (30k)
        System.assertEquals('Fulfillment', metrics.topWorkflowRisks[1].workflowStage);
        System.assertEquals(30000, metrics.topWorkflowRisks[1].aggregatedRisk);
        System.assertEquals(1, metrics.topWorkflowRisks[1].failureCount);
    }
}

