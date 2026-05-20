/**
 * Test class for TokenRotationScheduler
 */
@IsTest
private class TokenRotationSchedulerTest {

    @IsTest
    static void testScheduler() {
        TokenRotationScheduler.mockEndpointSecurity = true;
        Test.startTest();
        String jobId = System.schedule('Test Token Rotation', '0 0 0 * * ?', new TokenRotationScheduler());
        TokenRotationScheduler.rotateAndVerifyTokens();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled');
        
        List<Incident__c> incidents = [SELECT Id, Root_Cause__c FROM Incident__c];
        Boolean foundTokenExpiry = false;
        for (Incident__c inc : incidents) {
            if (inc.Root_Cause__c != null && inc.Root_Cause__c.containsIgnoreCase('Token Expiry Imminent')) {
                foundTokenExpiry = true;
                break;
            }
        }
        System.assertEquals(true, foundTokenExpiry, 'An incident should be created for expiring token');
    }
}

