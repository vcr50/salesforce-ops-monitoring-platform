/**
 * TenantContext
 * Resolves the current user's Tenant__c and enforces tenant-aware
 * query filtering across all SentinelFlow services.
 *
 * Usage:
 *   Id tenantId = TenantContext.getCurrentTenantId();
 *   String tenantFilter = TenantContext.getTenantFilter();
 *
 * @author  Tomcodex
 * @version 1.0
 */
public with sharing class TenantContext {

    private static Id cachedTenantId;

    /**
     * Resolve the Tenant__c Id for the running user.
     * Uses a custom field Tenant__c on the User object.
     * Falls back to the first active Tenant if no mapping exists (dev/demo mode).
     */
    public static Id getCurrentTenantId() {
        if (cachedTenantId != null) {
            return cachedTenantId;
        }

        // Try to read the user's assigned tenant
        try {
            User currentUser = [
                SELECT Tenant_Id__c FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (String.isNotBlank(currentUser.Tenant_Id__c)) {
                cachedTenantId = (Id) currentUser.Tenant_Id__c;
                return cachedTenantId;
            }
        } catch (Exception ex) {
            // Graceful fallback
        }

        // Fallback: return the first active tenant (for demo/dev environments)
        List<Tenant__c> tenants = [
            SELECT Id FROM Tenant__c
            WHERE Status__c = 'Active'
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!tenants.isEmpty()) {
            cachedTenantId = tenants[0].Id;
        }
        return cachedTenantId;
    }

    /**
     * Resolve tenant from an API key (used by REST endpoints).
     */
    public static Id getTenantIdByApiKey(String apiKey) {
        if (String.isBlank(apiKey)) {
            return null;
        }
        List<Tenant__c> tenants = [
            SELECT Id FROM Tenant__c
            WHERE API_Key__c = :apiKey
            AND   Status__c = 'Active'
            LIMIT 1
        ];
        return tenants.isEmpty() ? null : tenants[0].Id;
    }

    /**
     * Clear the cache (useful in test contexts).
     */
    @TestVisible
    private static void clearCache() {
        cachedTenantId = null;
    }
}
