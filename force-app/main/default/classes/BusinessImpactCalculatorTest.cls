@IsTest
private class BusinessImpactCalculatorTest {

    @TestSetup
    static void setup() {
        SecurityGate.bypassForTests = true;
        
        Incident__c inc1 = new Incident__c(
            Severity__c = 'Critical',
            Status__c = 'Open',
            Description__c = 'Billing System Downtime',
            Users_Affected__c = 1200
        );
        insert inc1;

        Incident__c inc2 = new Incident__c(
            Severity__c = 'High',
            Status__c = 'Open',
            Description__c = 'Stripe Connection Issue',
            Users_Affected__c = null
        );
        insert inc2;

        Incident__c inc3 = new Incident__c(
            Severity__c = 'Closed',
            Status__c = 'Closed',
            Description__c = 'Resolved incident'
        );
        insert inc3;
    }

    @IsTest
    static void testCalculate() {
        Test.startTest();
        BusinessImpactCalculator.ImpactResult res1 = BusinessImpactCalculator.calculate(null, null, null);
        BusinessImpactCalculator.ImpactResult res2 = BusinessImpactCalculator.calculate(100, 15.5, 'Orders API');
        Test.stopTest();

        System.assertEquals(0, res1.revenueAtRisk);
        System.assertEquals(1550, res2.revenueAtRisk);
    }

    @IsTest
    static void testCalculateForIncident() {
        SecurityGate.bypassForTests = true;
        Incident__c inc = [SELECT Id FROM Incident__c WHERE Severity__c = 'Critical' LIMIT 1];

        Test.startTest();
        BusinessImpactCalculator.ImpactResult res = BusinessImpactCalculator.calculateForIncident(inc.Id, 50.0);
        Test.stopTest();

        System.assertEquals(60000, res.revenueAtRisk);
    }

    @IsTest
    static void testCalculateForIncidentNull() {
        Test.startTest();
        try {
            BusinessImpactCalculator.calculateForIncident(null, 50.0);
            System.assert(false, 'Should have thrown exception');
        } catch (BusinessImpactCalculator.ImpactCalculationException e) {
            System.assert(e.getMessage().contains('Incident Id must not be null'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateForIncidentDefaultARPU() {
        SecurityGate.bypassForTests = true;
        Incident__c inc = [SELECT Id FROM Incident__c WHERE Severity__c = 'High' LIMIT 1];

        Test.startTest();
        BusinessImpactCalculator.ImpactResult res = BusinessImpactCalculator.calculateForIncident(inc.Id, null);
        Test.stopTest();

        // High default users = 500, default ARPU = 30.00
        System.assertEquals(15000, res.revenueAtRisk);
    }

    @IsTest
    static void testCalculateAllOpen() {
        SecurityGate.bypassForTests = true;
        Test.startTest();
        List<BusinessImpactCalculator.ImpactResult> results = BusinessImpactCalculator.calculateAllOpen();
        Test.stopTest();

        System.assert(results.size() >= 2);
    }

    @IsTest
    static void testGetOpenImpact() {
        SecurityGate.bypassForTests = true;
        Test.startTest();
        List<BusinessImpactCalculator.ImpactResult> results = BusinessImpactCalculator.getOpenImpact();
        Test.stopTest();

        System.assert(results.size() >= 2);
    }
}