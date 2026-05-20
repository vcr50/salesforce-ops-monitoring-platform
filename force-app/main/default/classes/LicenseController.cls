/**
 * LicenseController
 * AuraEnabled controller exposing license state to Lightning Web Components.
 *
 * Provides the frontend with:
 *   - Current plan, status, and expiry
 *   - Feature access map (which features are unlocked)
 *   - Upgrade prompts and trial countdown
 *
 * All validation is server-side. The frontend only reads state;
 * it cannot override or bypass plan checks.
 *
 * @author  Tomcodex
 * @version 2.7
 */
public with sharing class LicenseController {

    /**
     * Get the full license state for the current org.
     * Used by the subscription UI and feature-gated components.
     */
    @AuraEnabled(cacheable=true)
    public static LicenseService.LicenseInfo getLicenseInfo() {
        return LicenseCacheService.resolveWithCache();
    }

    /**
     * Get a map of all registered features and whether the current org can access them.
     * Key = Feature_Flag__mdt DeveloperName, Value = true/false
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getFeatureAccess() {
        return LicenseValidator.getFeatureAccessMap();
    }

    /**
     * Check if a single feature is accessible for the current org.
     *
     * @param featureName  DeveloperName of the Feature_Flag__mdt record
     * @return true if the feature is accessible
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isFeatureEnabled(String featureName) {
        return LicenseValidator.canAccess(featureName);
    }

    /**
     * Get the minimum plan required for a specific feature.
     * Used by the UI to show "Upgrade to Professional to unlock..." messages.
     *
     * @param featureName  DeveloperName of the Feature_Flag__mdt record
     * @return Plan name string (e.g., 'Professional')
     */
    @AuraEnabled(cacheable=true)
    public static String getRequiredPlanForFeature(String featureName) {
        return LicenseValidator.getRequiredPlan(featureName);
    }

    /**
     * Force refresh the license cache. Call after subscription upgrade/downgrade.
     * Non-cacheable because it mutates cache state.
     */
    @AuraEnabled
    public static LicenseService.LicenseInfo refreshLicense() {
        LicenseCacheService.invalidate();
        return LicenseCacheService.resolveWithCache();
    }

    /**
     * Get a summary object designed for the subscription upgrade page.
     * Combines license info with feature access for a single-call page load.
     */
    @AuraEnabled(cacheable=true)
    public static SubscriptionPageData getSubscriptionPageData() {
        LicenseService.LicenseInfo info = LicenseCacheService.resolveWithCache();
        Map<String, Boolean> features = LicenseValidator.getFeatureAccessMap();

        Integer incidentCount = [
            SELECT COUNT()
            FROM Incident__c
            WHERE CreatedDate = THIS_MONTH
            WITH USER_MODE
        ];

        SubscriptionPageData data = new SubscriptionPageData();
        data.license = info;
        data.features = features;
        data.currentMonthIncidents = incidentCount;
        data.incidentLimit = info.plan == LicenseService.PLAN_STARTER
            ? SubscriptionService.STARTER_INCIDENT_LIMIT
            : null;
        data.upgradeUrl = getUpgradeUrl(info.orgId);
        return data;
    }

    /**
     * Composite data object for the subscription page.
     */
    public class SubscriptionPageData {
        @AuraEnabled public LicenseService.LicenseInfo license;
        @AuraEnabled public Map<String, Boolean> features;
        @AuraEnabled public Integer currentMonthIncidents;
        @AuraEnabled public Integer incidentLimit;
        @AuraEnabled public String upgradeUrl;
    }

    private static String getUpgradeUrl(String orgId) {
        try {
            String baseUrl = System.Label.SentinelFlow_Billing_Upgrade_Url;
            return baseUrl + '?orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8');
        } catch (Exception e) {
            return '';
        }
    }
}

