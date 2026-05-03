@IsTest
private class WebsiteLeadConversionServiceTest {
    @IsTest
    static void convertsProfessionalWebsiteLeadToOpportunity() {
        Test.startTest();
        insert new Lead(
            FirstName = 'Priya',
            LastName = 'Sharma',
            Company = 'Acme India',
            Email = 'priya@example.com',
            LeadSource = 'Website',
            Description = 'Plan: Professional; Checkout: Pending'
        );
        Test.stopTest();

        Lead convertedLead = [
            SELECT IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
            FROM Lead
            WHERE Email = 'priya@example.com'
            LIMIT 1
        ];

        System.assertEquals(true, convertedLead.IsConverted);
        System.assertNotEquals(null, convertedLead.ConvertedAccountId);
        System.assertNotEquals(null, convertedLead.ConvertedContactId);
        System.assertNotEquals(null, convertedLead.ConvertedOpportunityId);

        Opportunity opportunity = [
            SELECT Name, StageName, Amount, CloseDate
            FROM Opportunity
            WHERE Id = :convertedLead.ConvertedOpportunityId
            LIMIT 1
        ];

        System.assertEquals('SentinelFlow Professional - Acme India', opportunity.Name);
        System.assertEquals('Qualification', opportunity.StageName);
        System.assertEquals(29, opportunity.Amount);
        System.assertEquals(Date.today().addDays(30), opportunity.CloseDate);
    }

    @IsTest
    static void ignoresStarterWebsiteLead() {
        Test.startTest();
        insert new Lead(
            FirstName = 'Dev',
            LastName = 'Starter',
            Company = 'Starter Co',
            Email = 'starter@example.com',
            LeadSource = 'Website',
            Description = 'Plan: Starter'
        );
        Test.stopTest();

        Lead leadRecord = [
            SELECT IsConverted
            FROM Lead
            WHERE Email = 'starter@example.com'
            LIMIT 1
        ];

        System.assertEquals(false, leadRecord.IsConverted);
    }

    @IsTest
    static void ignoresProfessionalNonWebsiteLead() {
        Test.startTest();
        insert new Lead(
            FirstName = 'Sales',
            LastName = 'Lead',
            Company = 'Offline Co',
            Email = 'offline@example.com',
            LeadSource = 'Partner Referral',
            Description = 'Plan: Professional; Checkout: Pending'
        );
        Test.stopTest();

        Lead leadRecord = [
            SELECT IsConverted
            FROM Lead
            WHERE Email = 'offline@example.com'
            LIMIT 1
        ];

        System.assertEquals(false, leadRecord.IsConverted);
    }
}
