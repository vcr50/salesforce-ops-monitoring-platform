trigger contactTrigger on contact__c (before insert) {
    for (contact__c c : Trigger.new) {
        if (c.Name != null) {
            c.Name = c.Name.trim();
        }
    }
}