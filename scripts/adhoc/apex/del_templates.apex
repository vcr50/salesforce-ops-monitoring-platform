List<EmailTemplate> templates = [SELECT Id, Name, DeveloperName, Folder.Name FROM EmailTemplate WHERE DeveloperName IN ('SentinelFlow_Lead_Welcome', 'SentinelFlow_Welcome_Email') ALL ROWS];
for (EmailTemplate t : templates) {
    System.debug('Found ALL ROWS: ' + t.Name + ' | ' + t.DeveloperName + ' | ' + t.Folder.Name);
}
if(!templates.isEmpty()){
    Database.emptyRecycleBin(templates);
    delete templates;
    Database.emptyRecycleBin(templates);
}
System.debug('Deleted ' + templates.size() + ' templates.');
