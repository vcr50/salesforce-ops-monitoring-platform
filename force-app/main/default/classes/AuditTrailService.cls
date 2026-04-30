/**
 * AuditTrailService
 * Writes immutable audit records to Audit_Trail__c on every significant
 * SentinelFlow action — API input, AI analysis, self-healing, escalations,
 * and manual status changes.
 *
 * v2.0 — Now records Record_Id__c and Tenant__c for full traceability.
 *
 * @author   Tomcodex
 */
public with sharing class AuditTrailService {

    /**
     * Log a single action synchronously.
     * Keep this call lightweight — never bulkify via DML inside a loop.
     * For batch scenarios use logAll().
     */
    public static void log(
        Id     recordId,
        String objectName,
        String action,
        String oldValue,
        String newValue
    ) {
        if (String.isBlank(objectName) || String.isBlank(action)) { return; }

        Audit_Trail__c trail  = new Audit_Trail__c();
        trail.Object_Name__c  = objectName;
        trail.Action__c       = action;
        trail.Old_Value__c    = oldValue;
        trail.New_Value__c    = newValue;
        trail.Timestamp__c    = System.now();

        // Link to specific record
        if (recordId != null) {
            trail.Record_Id__c = String.valueOf(recordId);
        }

        // Resolve tenant context
        try {
            trail.Tenant__c = TenantContext.getCurrentTenantId();
        } catch (Exception ex) {
            // Non-fatal — leave blank
        }

        // Resolve the running user
        try {
            trail.User__c = UserInfo.getUserId();
        } catch (Exception ex) {
            // Non-fatal — leave User__c blank
        }

        insert trail;
    }

    /**
     * Bulk log — use this inside trigger contexts to avoid DML-in-loop.
     */
    public static void logAll(List<Audit_Trail__c> entries) {
        if (entries == null || entries.isEmpty()) { return; }

        Id tenantId;
        try {
            tenantId = TenantContext.getCurrentTenantId();
        } catch (Exception ex) {
            // Non-fatal
        }

        for (Audit_Trail__c e : entries) {
            if (e.Timestamp__c == null) { e.Timestamp__c = System.now(); }
            if (e.Tenant__c == null && tenantId != null) { e.Tenant__c = tenantId; }
        }
        insert entries;
    }
}
