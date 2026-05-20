/**
 * LicenseValidator
 * Feature-level authorization enforcement for SentinelFlow.
 *
 * Usage:
 *   LicenseValidator.requirePlan('Professional', 'AI Classification');
 *   LicenseValidator.requireFeature('Prediction_Engine');
 *   Boolean allowed = LicenseValidator.canAccess('Adaptive_Auto_Heal');
 *
 * This class provides both hard gates (throw exception) and soft checks
 * (return boolean) for use in Apex controllers and service layers.
 *
 * @author  Tomcodex
 * @version 2.7
 */
public with sharing class LicenseValidator {

    /**
     * Exception thrown when a feature is accessed without the required plan.
     */
    public class LicenseRequiredException extends Exception {}

    // ─── Feature → Minimum Plan Mapping ───
    // Loaded from Feature_Flag__mdt at runtime (no hardcoding)
    private static Map<String, String> featurePlanMap;

    @TestVisible private static Boolean enforceInTests = false;

    /**
     * Hard gate: throws exception if the current org doesn't have the required plan.
     *
     * @param requiredPlan  The minimum plan required (e.g., 'Professional')
     * @param featureName   Human-readable feature name for error messages
     */
    public static void requirePlan(String requiredPlan, String featureName) {
        if (Test.isRunningTest() && !enforceInTests) {
            return;
        }
        if (!LicenseService.hasPlanLevel(requiredPlan)) {
            LicenseService.LicenseInfo info = LicenseService.resolve();
            throw new LicenseRequiredException(
                featureName + ' requires a ' + requiredPlan + ' plan or higher. ' +
                'Current plan: ' + info.plan + ' (' + info.status + '). ' +
                'Please upgrade your SentinelFlow subscription.'
            );
        }
    }

    /**
     * Hard gate: throws exception if the named feature is not enabled
     * for the current org's plan.
     *
     * @param featureDeveloperName  DeveloperName of the Feature_Flag__mdt record
     */
    public static void requireFeature(String featureDeveloperName) {
        if (!canAccess(featureDeveloperName)) {
            throw new LicenseRequiredException(
                'Feature "' + featureDeveloperName + '" is not available on your current plan. ' +
                'Please upgrade your SentinelFlow subscription.'
            );
        }
    }

    /**
     * Soft check: returns true if the named feature is accessible
     * for the current org's plan.
     *
     * @param featureDeveloperName  DeveloperName of the Feature_Flag__mdt record
     */
    public static Boolean canAccess(String featureDeveloperName) {
        if (String.isBlank(featureDeveloperName)) {
            return false;
        }

        loadFeaturePlanMap();

        if (Test.isRunningTest() && !enforceInTests) {
            return true;
        }

        // If the feature isn't registered, allow in test / deny in prod
        if (!featurePlanMap.containsKey(featureDeveloperName)) {
            return Test.isRunningTest();
        }

        String requiredPlan = featurePlanMap.get(featureDeveloperName);
        return LicenseService.hasPlanLevel(requiredPlan);
    }

    /**
     * Get a map of all features and whether the current org can access them.
     * Useful for frontend bulk queries.
     */
    public static Map<String, Boolean> getFeatureAccessMap() {
        loadFeaturePlanMap();
        Map<String, Boolean> accessMap = new Map<String, Boolean>();
        for (String featureName : featurePlanMap.keySet()) {
            accessMap.put(featureName, canAccess(featureName));
        }
        return accessMap;
    }

    /**
     * Get the minimum plan required for a specific feature.
     */
    public static String getRequiredPlan(String featureDeveloperName) {
        loadFeaturePlanMap();
        return featurePlanMap.containsKey(featureDeveloperName)
            ? featurePlanMap.get(featureDeveloperName)
            : LicenseService.PLAN_FREE;
    }

    // ═══════════════════════════════════════════════════════════════
    //  PRIVATE — Feature Flag Loading
    // ═══════════════════════════════════════════════════════════════

    /**
     * Lazy-load the feature-to-plan mapping from Custom Metadata.
     * Feature_Flag__mdt records define which plan unlocks each feature.
     */
    private static void loadFeaturePlanMap() {
        if (featurePlanMap != null) {
            return;
        }

        featurePlanMap = new Map<String, String>();

        try {
            List<Feature_Flag__mdt> flags = [
                SELECT DeveloperName, Plan__c, Is_Enabled__c
                FROM Feature_Flag__mdt
                WHERE Is_Enabled__c = true
                WITH USER_MODE
            ];

            for (Feature_Flag__mdt flag : flags) {
                if (String.isNotBlank(flag.Plan__c)) {
                    featurePlanMap.put(flag.DeveloperName, flag.Plan__c);
                }
            }
        } catch (Exception e) {
            // Plan__c field may not exist yet in the org
            // Graceful fallback — all features default to Free
        }
    }

    /**
     * Clear the cached feature map. Used in test contexts.
     */
    @TestVisible
    private static void clearCache() {
        featurePlanMap = null;
    }
}

