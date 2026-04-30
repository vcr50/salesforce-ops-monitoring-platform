/**
 * FeatureFlag
 * Utility class to check custom metadata feature flags per tenant.
 *
 * @author Tomcodex
 * @version 1.0
 */
public with sharing class FeatureFlag {

    public static Boolean isEnabled(String featureName, Id tenantId) {
        if (String.isBlank(featureName)) return false;
        
        List<Feature_Flag__mdt> flags = [
            SELECT Is_Enabled__c, Tenant_ID__c 
            FROM Feature_Flag__mdt 
            WHERE DeveloperName = :featureName
            WITH USER_MODE
        ];

        if (flags.isEmpty()) {
            return false;
        }

        // Check for tenant-specific flag
        if (tenantId != null) {
            for (Feature_Flag__mdt flag : flags) {
                if (flag.Tenant_ID__c == String.valueOf(tenantId) && flag.Is_Enabled__c) {
                    return true;
                }
            }
        }

        // Check for global flag
        for (Feature_Flag__mdt flag : flags) {
            if (String.isBlank(flag.Tenant_ID__c)) {
                return flag.Is_Enabled__c;
            }
        }

        return false;
    }

    public static Boolean isEnabled(String featureName) {
        return isEnabled(featureName, TenantContext.getCurrentTenantId());
    }
}
