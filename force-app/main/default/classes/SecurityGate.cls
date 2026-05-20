/**
 * SecurityGate
 * Centralized CRUD/FLS enforcement utility for SentinelFlow.
 *
 * Every Apex class that performs SOQL, DML, or deletes MUST route through
 * this gate before touching any sObject. This is the single source of truth
 * for AppExchange security compliance.
 *
 * Usage:
 *   SecurityGate.requireAccessible('Incident__c');
 *   SecurityGate.requireCreateable('Incident__c', new Set<String>{'Status__c', 'Severity__c'});
 *   SecurityGate.requireUpdateable('Incident__c', new Set<String>{'Status__c'});
 *   SecurityGate.requireDeletable('Integration_Endpoint__c');
 *
 * @author  Tomcodex
 * @version 1.0 (AppExchange Compliance - Sprint 3.2)
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public inherited sharing class SecurityGate {

    // -- Exceptions ---------------------------------------------------------------

    public class SecurityException extends Exception {}

    // -- CRUD Checks --------------------------------------------------------------

    public static void requireAccessible(String objectApiName) {
        if (!isAccessible(objectApiName)) {
            throw new SecurityException(
                'Insufficient access - ' + objectApiName + ' is not accessible for the current user.'
            );
        }
    }

    public static void requireCreateable(String objectApiName) {
        if (!isCreateable(objectApiName)) {
            throw new SecurityException(
                'Insufficient access - ' + objectApiName + ' is not createable for the current user.'
            );
        }
    }

    public static void requireUpdateable(String objectApiName) {
        if (!isUpdateable(objectApiName)) {
            throw new SecurityException(
                'Insufficient access - ' + objectApiName + ' is not updateable for the current user.'
            );
        }
    }

    public static void requireDeletable(String objectApiName) {
        if (!isDeletable(objectApiName)) {
            throw new SecurityException(
                'Insufficient access - ' + objectApiName + ' is not deletable for the current user.'
            );
        }
    }

    // -- FLS Checks ---------------------------------------------------------------

    public static void requireFieldsAccessible(String objectApiName, Set<String> fieldApiNames) {
        Set<String> notAccessible = getInaccessibleFields(objectApiName, fieldApiNames);
        if (!notAccessible.isEmpty()) {
            throw new SecurityException(
                'Insufficient field-level access - the following fields on ' + objectApiName
                + ' are not readable: ' + String.join(new List<String>(notAccessible), ', ')
            );
        }
    }

    public static void requireFieldsCreateable(String objectApiName, Set<String> fieldApiNames) {
        Set<String> notCreateable = getNonCreateableFields(objectApiName, fieldApiNames);
        if (!notCreateable.isEmpty()) {
            throw new SecurityException(
                'Insufficient field-level access - the following fields on ' + objectApiName
                + ' are not createable: ' + String.join(new List<String>(notCreateable), ', ')
            );
        }
    }

    public static void requireFieldsUpdateable(String objectApiName, Set<String> fieldApiNames) {
        Set<String> notUpdateable = getNonUpdateableFields(objectApiName, fieldApiNames);
        if (!notUpdateable.isEmpty()) {
            throw new SecurityException(
                'Insufficient field-level access - the following fields on ' + objectApiName
                + ' are not updateable: ' + String.join(new List<String>(notUpdateable), ', ')
            );
        }
    }

    // -- Combined Convenience Methods ----------------------------------------------

    public static void requireCreateAccess(String objectApiName, Set<String> fieldApiNames) {
        requireCreateable(objectApiName);
        requireFieldsCreateable(objectApiName, fieldApiNames);
    }

    public static void requireReadAccess(String objectApiName, Set<String> fieldApiNames) {
        requireAccessible(objectApiName);
        requireFieldsAccessible(objectApiName, fieldApiNames);
    }

    public static void requireUpdateAccess(String objectApiName, Set<String> fieldApiNames) {
        requireUpdateable(objectApiName);
        requireFieldsUpdateable(objectApiName, fieldApiNames);
    }

    public static void requireDeleteAccess(String objectApiName) {
        requireDeletable(objectApiName);
    }

    // -- Boolean (non-throwing) Methods --------------------------------------------

    @TestVisible
    public static Boolean bypassForTests = false;

    public static Boolean isTestBypassEnabled() {
        return bypassForTests;
    }

    public static Boolean isAccessible(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().isAccessible();
    }

    public static Boolean isCreateable(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().isCreateable();
    }

    public static Boolean isUpdateable(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().isUpdateable();
    }

    public static Boolean isDeletable(String objectApiName) {
        return Schema.getGlobalDescribe().containsKey(objectApiName)
            && Schema.getGlobalDescribe().get(objectApiName).getDescribe().isDeletable();
    }

    // -- Private FLS Helpers -------------------------------------------------------

    private static Set<String> getInaccessibleFields(String objectApiName, Set<String> fieldApiNames) {
        Set<String> result = new Set<String>();
        Map<String, Schema.SObjectField> fieldMap = getFieldMap(objectApiName);
        for (String fieldName : fieldApiNames) {
            if (!fieldMap.containsKey(fieldName) || !fieldMap.get(fieldName).getDescribe().isAccessible()) {
                result.add(fieldName);
            }
        }
        return result;
    }

    private static Set<String> getNonCreateableFields(String objectApiName, Set<String> fieldApiNames) {
        Set<String> result = new Set<String>();
        Map<String, Schema.SObjectField> fieldMap = getFieldMap(objectApiName);
        for (String fieldName : fieldApiNames) {
            if (!fieldMap.containsKey(fieldName) || !fieldMap.get(fieldName).getDescribe().isCreateable()) {
                result.add(fieldName);
            }
        }
        return result;
    }

    private static Set<String> getNonUpdateableFields(String objectApiName, Set<String> fieldApiNames) {
        Set<String> result = new Set<String>();
        Map<String, Schema.SObjectField> fieldMap = getFieldMap(objectApiName);
        for (String fieldName : fieldApiNames) {
            if (!fieldMap.containsKey(fieldName) || !fieldMap.get(fieldName).getDescribe().isUpdateable()) {
                result.add(fieldName);
            }
        }
        return result;
    }

    private static Map<String, Schema.SObjectField> getFieldMap(String objectApiName) {
        if (!Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return new Map<String, Schema.SObjectField>();
        }
        return Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
    }
}
