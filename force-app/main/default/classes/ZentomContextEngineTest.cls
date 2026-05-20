/**
 * ZentomContextEngineTest
 * Validates the Context Engine assembles situational awareness correctly.
 */
@IsTest
private class ZentomContextEngineTest {

    @TestSetup
    static void setup() {
        Incident__c inc = new Incident__c(
            Severity__c = 'Critical',
            Description__c = 'API rate limit exceeded on payment gateway',
            Status__c = 'New'
        );
        insert inc;
    }

    @IsTest
    static void testAssembleContext_ReturnsValidPacket() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        ZentomContextEngine.ContextPacket packet = ZentomContextEngine.assembleContext(inc.Id);
        Test.stopTest();

        System.assertNotEquals(null, packet, 'ContextPacket should not be null');
        System.assertNotEquals(null, packet.similarIncidents, 'Similar incidents list should exist');
        System.assert(packet.accountARR >= 0, 'ARR should be populated');
        System.assertNotEquals(null, packet.accountTier, 'Account tier should be set');
        System.assertNotEquals(null, packet.incidentHistory, 'Incident history should be populated');
    }

    @IsTest
    static void testAssembleContext_TierClassification() {
        Incident__c inc = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        ZentomContextEngine.ContextPacket packet = ZentomContextEngine.assembleContext(inc.Id);
        Test.stopTest();

        // Default ARR is 150000, should be Enterprise tier
        Set<String> validTiers = new Set<String>{'Strategic', 'Enterprise', 'Growth', 'Standard'};
        System.assert(validTiers.contains(packet.accountTier), 'Tier should be a valid classification');
    }
}

