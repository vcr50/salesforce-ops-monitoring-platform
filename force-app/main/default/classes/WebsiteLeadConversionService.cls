public with sharing class WebsiteLeadConversionService {
    @TestVisible private static Boolean isRunning = false;
    @TestVisible private static String convertedStatusOverride;

    public static void convertProfessionalWebsiteLeads(List<Lead> leads) {
        if (isRunning || leads == null || leads.isEmpty()) {
            return;
        }

        List<Id> leadIds = new List<Id>();
        for (Lead leadRecord : leads) {
            if (isProfessionalWebsiteLead(leadRecord)) {
                leadIds.add(leadRecord.Id);
            }
        }

        if (leadIds.isEmpty()) {
            return;
        }

        isRunning = true;
        try {
            convertLeadIds(leadIds);
        } finally {
            isRunning = false;
        }
    }

    private static Boolean isProfessionalWebsiteLead(Lead leadRecord) {
        return leadRecord != null
            && leadRecord.Id != null
            && leadRecord.IsConverted == false
            && leadRecord.LeadSource == 'Website'
            && leadRecord.Description != null
            && leadRecord.Description.containsIgnoreCase('Professional');
    }

    private static void convertLeadIds(List<Id> leadIds) {
        List<Lead> leadsToConvert = [
            SELECT Id, Company, Description, Email, FirstName, IsConverted, LastName, LeadSource
            FROM Lead
            WHERE Id IN :leadIds
            AND IsConverted = false
        ];

        if (leadsToConvert.isEmpty()) {
            return;
        }

        Map<String, Account> accountsByName = getAccountsByName(leadsToConvert);
        String convertedStatus = getConvertedStatus();

        List<Database.LeadConvert> conversions = new List<Database.LeadConvert>();
        for (Lead leadRecord : leadsToConvert) {
            Database.LeadConvert conversion = new Database.LeadConvert();
            conversion.setLeadId(leadRecord.Id);
            conversion.setConvertedStatus(convertedStatus);
            conversion.setDoNotCreateOpportunity(false);
            conversion.setOpportunityName(buildOpportunityName(leadRecord));

            Account existingAccount = accountsByName.get(normalizeName(leadRecord.Company));
            if (existingAccount != null) {
                conversion.setAccountId(existingAccount.Id);
            }

            conversions.add(conversion);
        }

        List<Database.LeadConvertResult> results = Database.convertLead(conversions, false);
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Database.LeadConvertResult result : results) {
            if (result.isSuccess() && result.getOpportunityId() != null) {
                opportunitiesToUpdate.add(new Opportunity(
                    Id = result.getOpportunityId(),
                    StageName = 'Qualification',
                    Amount = 29,
                    CloseDate = Date.today().addDays(30)
                ));
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    private static Map<String, Account> getAccountsByName(List<Lead> leadsToConvert) {
        Set<String> accountNames = new Set<String>();
        for (Lead leadRecord : leadsToConvert) {
            String normalized = normalizeName(leadRecord.Company);
            if (normalized != null) {
                accountNames.add(normalized);
            }
        }

        Map<String, Account> accountsByName = new Map<String, Account>();
        if (accountNames.isEmpty()) {
            return accountsByName;
        }

        for (Account accountRecord : [
            SELECT Id, Name
            FROM Account
            WHERE Name IN :accountNames
        ]) {
            accountsByName.put(normalizeName(accountRecord.Name), accountRecord);
        }

        return accountsByName;
    }

    private static String getConvertedStatus() {
        if (String.isNotBlank(convertedStatusOverride)) {
            return convertedStatusOverride;
        }

        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];
        return convertedStatus.MasterLabel;
    }

    private static String buildOpportunityName(Lead leadRecord) {
        String company = String.isBlank(leadRecord.Company) ? 'Website Lead' : leadRecord.Company.trim();
        return 'SentinelFlow Professional - ' + company;
    }

    private static String normalizeName(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}
