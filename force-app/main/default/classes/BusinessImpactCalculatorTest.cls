/**
 * BusinessImpactCalculatorTest
 * @author   Tomcodex
 */
@IsTest
private class BusinessImpactCalculatorTest {

    @IsTest
    static void testCalculateCriticalRisk() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(2000, 50.00, 'Payment Integration');

        System.assertEquals(100000, r.revenueAtRisk, 'Revenue should be 2000 × 50');
        System.assertEquals('Critical', r.riskLevel,  'Should be Critical');
        System.assert(r.summary.contains('Critical'),  'Summary should mention Critical');
    }

    @IsTest
    static void testCalculateHighRisk() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(500, 30.00, 'ERP Sync');

        System.assertEquals(15000,  r.revenueAtRisk);
        System.assertEquals('High', r.riskLevel);
    }

    @IsTest
    static void testCalculateMediumRisk() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(100, 20.00, 'Data Import');

        System.assertEquals(2000,     r.revenueAtRisk);
        System.assertEquals('Medium', r.riskLevel);
    }

    @IsTest
    static void testCalculateLowRisk() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(10, 5.00, 'Notification Service');

        System.assertEquals(50,    r.revenueAtRisk);
        System.assertEquals('Low', r.riskLevel);
    }

    @IsTest
    static void testZeroUsers() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(0, 40.00, 'Test');

        System.assertEquals(0,     r.revenueAtRisk);
        System.assertEquals('Low', r.riskLevel);
    }

    @IsTest
    static void testNullInputsDefaultToZero() {
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculate(null, null, null);

        System.assertEquals(0, r.revenueAtRisk, 'Null inputs should produce zero revenue');
    }

    @IsTest
    static void testCalculateForIncident() {
        Environment__c env = new Environment__c(Name = 'Production');
        insert env;

        Incident__c inc = new Incident__c(
            Severity__c      = 'Critical',
            Status__c        = 'New',
            Description__c   = 'Test incident',
            Users_Affected__c = 1000,
            Environment__c   = env.Id
        );
        insert inc;

        Test.startTest();
        BusinessImpactCalculator.ImpactResult r =
            BusinessImpactCalculator.calculateForIncident(inc.Id, 42.00);
        Test.stopTest();

        System.assertEquals(42000,    r.revenueAtRisk);
        System.assertEquals('High', r.riskLevel);
        Incident__c updated = [SELECT Revenue_at_Risk__c FROM Incident__c WHERE Id = :inc.Id];
        System.assertEquals(42000, updated.Revenue_at_Risk__c, 'Revenue should be persisted');
    }

    @IsTest
    static void testNullIncidentIdThrows() {
        Boolean threw = false;
        try {
            BusinessImpactCalculator.calculateForIncident(null, 30.00);
        } catch (BusinessImpactCalculator.ImpactCalculationException e) {
            threw = true;
        }
        System.assert(threw, 'Expected exception for null Id');
    }
}
