@IsTest
private class SentinelFlowPostInstallHandlerTest {
    @IsTest
    static void installCreatesTrialAndSchedulesExpiry() {
        Test.startTest();
        Test.testInstall(new SentinelFlowPostInstallHandler(), null);
        Test.stopTest();

        Subscription__c subscription = [
            SELECT Org_Id__c, Plan__c, Status__c, Expiry_Date__c
            FROM Subscription__c
            WHERE Org_Id__c = :UserInfo.getOrganizationId()
            LIMIT 1
        ];

        System.assertEquals('Starter', subscription.Plan__c);
        System.assertEquals('Trial', subscription.Status__c);
        System.assertEquals(Date.today().addDays(14), subscription.Expiry_Date__c);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM CronTrigger
                WHERE CronJobDetail.Name = 'SentinelFlow Subscription Trial Expiry'
            ]
        );
    }
}
