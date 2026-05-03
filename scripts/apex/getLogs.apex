List<ApexLog> logs = [SELECT Id, Operation, Status, LogLength FROM ApexLog ORDER BY StartTime DESC LIMIT 5];
for(ApexLog l : logs) {
    System.debug(l);
}
