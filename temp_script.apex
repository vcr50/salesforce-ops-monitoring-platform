Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('Feature_Flag__mdt').getDescribe().fields.getMap();
for(String fieldName : fields.keySet()) {
    System.debug(fieldName + ' - ' + fields.get(fieldName).getDescribe().getType());
}
