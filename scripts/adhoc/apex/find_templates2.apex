List<EmailTemplate> templates = [SELECT Id, Name, DeveloperName, FolderId, Folder.Name, Folder.Type, IsActive FROM EmailTemplate WHERE Name LIKE '%SentinelFlow%'];
System.debug('FOUND ' + templates.size() + ' templates');
for (EmailTemplate et : templates) {
    System.debug(et.Id + ' - ' + et.Name + ' - ' + et.DeveloperName + ' - Folder: ' + et.FolderId + ' (' + et.Folder.Name + ' - ' + et.Folder.Type + ')');
}
