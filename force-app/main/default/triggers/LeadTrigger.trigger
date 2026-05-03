trigger LeadTrigger on Lead (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        WebsiteLeadConversionService.convertProfessionalWebsiteLeads(Trigger.new);
    }
}
