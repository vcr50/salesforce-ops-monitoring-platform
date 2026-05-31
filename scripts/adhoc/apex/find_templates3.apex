List<EmailTemplate> templates = [SELECT Id, Name, DeveloperName FROM EmailTemplate WHERE Name LIKE '%SentinelFlow%' ALL ROWS];
System.debug('FOUND ' + templates.size() + ' templates');
for (EmailTemplate et : templates) {
    System.debug(et.Id + ' - ' + et.Name + ' - ' + et.DeveloperName);
}
