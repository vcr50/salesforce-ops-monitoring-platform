/**
 * SystemLogger
 * Centralized error logging utility for the SEOMP platform.
 * Supports failure classification (Transient/Permanent) and retry tracking.
 *
 * @author Tomcodex
 * @version 2.0
 */
public without sharing class SystemLogger {
    
    public enum ErrorType { TRANSIENT_ERROR, PERMANENT_ERROR }

    public static void logError(Exception ex, String className, String methodName, ErrorType type, Integer retryCount, Id tenantId) {
        try {
            System_Log__c log = new System_Log__c();
            log.Class_Name__c = className;
            log.Method_Name__c = methodName;
            log.Exception_Message__c = ex.getMessage();
            log.Stack_Trace__c = ex.getStackTraceString();
            log.Error_Type__c = type == ErrorType.TRANSIENT_ERROR ? 'Transient' : 'Permanent';
            log.Retry_Count__c = retryCount;
            log.Tenant__c = tenantId;
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SystemLogger failed to write log: ' + e.getMessage());
        }
    }

    public static void logError(Exception ex, String className, String methodName) {
        logError(ex, className, methodName, ErrorType.PERMANENT_ERROR, 0, null);
    }
}
