@isTest
public class ContactTriggerTest {
    @isTest
    static void testInsertContact() {
        contact__c c = new contact__c(Name = ' Test Contact ');
        Test.startTest();
        insert c;
        Test.stopTest();
        
        contact__c inserted = [SELECT Name FROM contact__c WHERE Id = :c.Id];
        System.assertEquals('Test Contact', inserted.Name, 'Name should be trimmed');
    }
}
