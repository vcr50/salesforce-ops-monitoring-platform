/**
 * BusinessGraphEngineTest
 * Test class covering Phase 2 logic to map universal events to pipeline impact.
 *
 * @author SentinelFlow
 * @version 1.0
 */
@IsTest
private class BusinessGraphEngineTest {
    
    @TestSetup
    static void setup() {
        // Create dummy opportunities
        List<Opportunity> opps = new List<Opportunity>();
        opps.add(new Opportunity(Name='Enterprise Deal A', StageName='Prospecting', Amount=250000, CloseDate=System.today().addDays(30)));
        opps.add(new Opportunity(Name='Mid-Market Deal B', StageName='Qualification', Amount=50000, CloseDate=System.today().addDays(15)));
        insert opps;
    }

    @IsTest
    static void testEnrichUniversalEvents_PaymentStage() {
        List<Universal_Event__c> events = new List<Universal_Event__c>();
        
        Universal_Event__c ev = new Universal_Event__c(
            Event_Key__c = 'Test:123',
            Workflow_Stage__c = 'Payment',
            Revenue_Risk__c = 0,
            Recovery_Possible__c = true,
            Status__c = 'New'
        );
        events.add(ev);

        Test.startTest();
        BusinessGraphEngine.enrichUniversalEvents(events);
        Test.stopTest();
        
        // Assert that the highest value Opp ($250,000) was linked to the Revenue Risk
        System.assertEquals(250000, ev.Revenue_Risk__c);
        System.assert(ev.Business_Impact__c.contains('Enterprise Deal A'), 'Should mention the highest value deal');
    }
    
    @IsTest
    static void testEnrichUniversalEvents_LeadCaptureStage() {
        List<Universal_Event__c> events = new List<Universal_Event__c>();
        
        Universal_Event__c ev = new Universal_Event__c(
            Event_Key__c = 'Test:Lead:1',
            Workflow_Stage__c = 'Lead Capture',
            Revenue_Risk__c = 0,
            Recovery_Possible__c = true,
            Status__c = 'New'
        );
        events.add(ev);

        Test.startTest();
        BusinessGraphEngine.enrichUniversalEvents(events);
        Test.stopTest();
        
        // Assert that the average of the two Opps ($150,000) was linked
        System.assertEquals(150000, ev.Revenue_Risk__c);
        System.assert(ev.Business_Impact__c.contains('Average pipeline loss exposure: $150000'), 'Should average pipeline');
    }

    @IsTest
    static void testEnrichUniversalEvents_EmptyList() {
        // Ensure no null pointer exceptions
        Test.startTest();
        BusinessGraphEngine.enrichUniversalEvents(new List<Universal_Event__c>());
        BusinessGraphEngine.enrichUniversalEvents(null);
        Test.stopTest();
        
        System.assert(true, 'Executed without exceptions');
    }
}

