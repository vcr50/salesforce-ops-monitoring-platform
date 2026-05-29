@IsTest
private class RevenuePulseServiceTest {
    @TestSetup
    static void setup() {
        SecurityGate.bypassForTests = true;
        
        Incident__c inc1 = new Incident__c(
            Severity__c = 'Critical',
            Status__c = 'New',
            Description__c = 'Critical revenue block',
            Recommended_Action__c = 'Restart Gateway',
            AI_Impact_Level__c = 'Critical',
            Users_Affected__c = 1000
        );
        
        Incident__c inc2 = new Incident__c(
            Severity__c = 'High',
            Status__c = 'New',
            Description__c = 'High revenue block',
            Recommended_Action__c = 'Restart DB',
            AI_Impact_Level__c = 'High',
            Users_Affected__c = 500
        );
        
        insert new List<Incident__c>{inc1, inc2};
    }

    @IsTest
    static void testExecutePulseSync() {
        SecurityGate.bypassForTests = true;

        Test.startTest();
        RevenuePulseService.executePulseSync();
        Test.stopTest();

        List<Revenue_Risk__c> risks = [SELECT Id, Risk_Level__c, Status__c, Affected_Pipeline__c FROM Revenue_Risk__c];
        System.assertEquals(2, risks.size(), 'Should have created 2 revenue risk records');
        
        // Execute again to test existing risk updates
        RevenuePulseService.executePulseSync();
        List<Revenue_Risk__c> risksAfter = [SELECT Id FROM Revenue_Risk__c];
        System.assertEquals(2, risksAfter.size(), 'Should not duplicate revenue risk records');
    }

    @IsTest
    static void testGetOrgRiskSummary() {
        SecurityGate.bypassForTests = true;

        RevenuePulseService.executePulseSync();

        Test.startTest();
        RevenuePulseService.RiskSummaryDTO summary = RevenuePulseService.getOrgRiskSummary();
        Test.stopTest();

        System.assert(summary.openRisksCount > 0, 'Should have open risks');
        System.assert(summary.topActions.size() > 0, 'Should have top actions');
        System.assertNotEquals(null, summary.totalRiskAmount, 'Should have total risk amount');
    }
}
