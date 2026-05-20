/**
 * OperationalMemoryEngineTest
 * Test coverage for Phase 4 Operational Memory Engine.
 */
@IsTest
private class OperationalMemoryEngineTest {

    @IsTest
    static void testArchiveIncidentToMemory() {
        // Create an incident
        Incident__c inc = new Incident__c(
            Status__c = 'Resolved',
            Severity__c = 'High',
            Revenue_at_Risk__c = 5000,
            Root_Cause__c = 'Test Error',
            Recommended_Action__c = 'Retry',
            AI_Confidence__c = 95.0
        );
        insert inc;
        
        // Add AI Decision
        AI_Decision__c decision = new AI_Decision__c(
            Incident__c = inc.Id,
            Recommended_Action__c = 'Retry',
            Confidence_Score__c = 95.0,
            Auto_Executed__c = true
        );
        insert decision;
        
        // Add Auto Heal Run
        Auto_Heal_Run__c heal = new Auto_Heal_Run__c(
            Incident__c = inc.Id,
            Action_Taken__c = 'Retry',
            Result__c = 'Succeeded',
            Retry_Attempt__c = 1
        );
        insert heal;

        Test.startTest();
        OperationalMemoryEngine.archiveIncidentToMemory(new List<Id>{ inc.Id });
        Test.stopTest();

        // Verify the Audit Trail was created
        List<Audit_Trail__c> trails = [SELECT Id, Action__c, New_Value__c FROM Audit_Trail__c WHERE Object_Name__c = 'Operational_Memory'];
        System.assertEquals(1, trails.size(), 'Should have created one Operational Memory log.');
        System.assertEquals('Archive Resolution Path', trails[0].Action__c);
        
        // Verify JSON payload contains key information
        String jsonPayload = trails[0].New_Value__c;
        System.assert(jsonPayload.contains('Test Error'));
        System.assert(jsonPayload.contains('Retry'));
        System.assert(jsonPayload.contains('Succeeded'));
        System.assert(jsonPayload.contains('95'));
    }
}

