@IsTest
private class LegacyOrgCoverageTest {
    @IsTest
    static void utilityAndTrainingClassesAreCovered() {
        Test.startTest();
        AccountRecord.insertData('Coverage Account', 'Hot', 'https://example.com');
        AccountRecord.insertContact();
        Block2.sumValues();
        ConditionalStmtDemo.max(10, 25);
        LoopDemo.SumOfNaturalNums(5);
        OpportunityQuery.hello();
        Rectangle.area();

        Square square = new Square(5);
        square.area();
        square.Perimeter();
        Test.stopTest();

        System.assertEquals('Ada Lovelace', nameController.concatNames('Ada', 'Lovelace'));
        System.assertEquals(true, stringCheckController.keywordExist('salesforce automation'));
        System.assertEquals(false, stringCheckController.keywordExist('platform ops'));
        System.assertEquals(false, stringCheckController.keywordExist('   '));
    }
}
