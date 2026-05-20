/**
 * LicenseService
 * Central license resolution engine for SentinelFlow ISV licensing.
 *
 * Resolution order:
 *   1. Transaction-level static cache
 *   2. Platform Cache (Org partition)
 *   3. Salesforce PackageLicense object (managed package license)
 *   4. Subscription__c record (billing-driven fallback)
 *
 * This class NEVER hardcodes org IDs or sandbox checks.
 * All plan resolution is dynamic and data-driven.
 *
 * @author  Tomcodex
 * @version 2.7
 */
public with sharing class LicenseService {

    // ─── Plan Constants ───
    public static final String PLAN_FREE      = 'Free';
    public static final String PLAN_STARTER   = 'Starter';
    public static final String PLAN_PRO       = 'Professional';
    public static final String PLAN_ENTERPRISE = 'Enterprise';

    // ─── Status Constants ───
    public static final String STATUS_ACTIVE    = 'Active';
    public static final String STATUS_TRIAL     = 'Trial';
    public static final String STATUS_EXPIRED   = 'Expired';
    public static final String STATUS_SUSPENDED = 'Suspended';
    public static final String STATUS_GRACE     = 'Grace';

    // ─── Plan Hierarchy (higher index = more features) ───
    private static final List<String> PLAN_HIERARCHY = new List<String>{
        PLAN_FREE, PLAN_STARTER, PLAN_PRO, PLAN_ENTERPRISE
    };

    // ─── Transaction cache ───
    private static LicenseInfo cachedLicenseInfo;

    /**
     * Immutable value object representing the resolved license state.
     */
    public class LicenseInfo {
        @AuraEnabled public String plan        { get; private set; }
        @AuraEnabled public String status      { get; private set; }
        @AuraEnabled public Date   expiryDate  { get; private set; }
        @AuraEnabled public Integer daysRemaining { get; private set; }
        @AuraEnabled public Boolean isActive   { get; private set; }
        @AuraEnabled public Boolean inGracePeriod { get; private set; }
        @AuraEnabled public String  packageVersion { get; private set; }
        @AuraEnabled public String  orgId      { get; private set; }

        public LicenseInfo(
            String plan, String status, Date expiryDate,
            Boolean isActive, Boolean inGracePeriod, String packageVersion
        ) {
            this.plan = plan;
            this.status = status;
            this.expiryDate = expiryDate;
            this.daysRemaining = expiryDate != null
                ? Date.today().daysBetween(expiryDate)
                : null;
            this.isActive = isActive;
            this.inGracePeriod = inGracePeriod;
            this.packageVersion = packageVersion;
            this.orgId = UserInfo.getOrganizationId();
        }
    }

    /**
     * Resolve the current org's license. Uses transaction cache if available.
     */
    public static LicenseInfo resolve() {
        if (cachedLicenseInfo != null) {
            return cachedLicenseInfo;
        }
        cachedLicenseInfo = resolveFromSources();
        return cachedLicenseInfo;
    }

    /**
     * Force a fresh license resolution (bypasses transaction cache).
     */
    public static LicenseInfo resolveRefresh() {
        cachedLicenseInfo = null;
        return resolve();
    }

    /**
     * Check if the current org has at least the given plan level.
     */
    public static Boolean hasPlanLevel(String requiredPlan) {
        LicenseInfo info = resolve();
        if (!info.isActive && !info.inGracePeriod) {
            return false;
        }
        return getPlanRank(info.plan) >= getPlanRank(requiredPlan);
    }

    /**
     * Get the current resolved plan name.
     */
    public static String getCurrentPlan() {
        return resolve().plan;
    }

    /**
     * Check if the license is functionally active (includes grace period).
     */
    public static Boolean isLicenseActive() {
        LicenseInfo info = resolve();
        return info.isActive || info.inGracePeriod;
    }

    /**
     * Clear the transaction-level cache.
     * Called by LicenseCacheService.invalidate() and in test contexts.
     */
    public static void clearCache() {
        cachedLicenseInfo = null;
    }

    // ═══════════════════════════════════════════════════════════════
    //  PRIVATE — Resolution Pipeline
    // ═══════════════════════════════════════════════════════════════

    private static LicenseInfo resolveFromSources() {
        // 1. Try Salesforce PackageLicense (managed package native licensing)
        LicenseInfo fromPackage = resolveFromPackageLicense();
        if (fromPackage != null) {
            return fromPackage;
        }

        // 2. Fallback to Subscription__c (billing-driven)
        return resolveFromSubscription();
    }

    /**
     * Attempt to read the Salesforce PackageLicense object.
     * This object is auto-populated by Salesforce when a managed package
     * with an associated LMA license is installed.
     */
    private static LicenseInfo resolveFromPackageLicense() {
        try {
            // Namespace-safe query for SentinelFlow's managed package
            String namespace = getNamespace();
            if (String.isBlank(namespace)) {
                return null; // Not running as a managed package
            }

            // Query PackageLicense — available in all orgs with managed packages
            List<SObject> licenses = Database.query(
                'SELECT Status, ExpirationDate, AllowedLicenses, UsedLicenses ' +
                'FROM PackageLicense ' +
                'WHERE NamespacePrefix = :namespace ' +
                'LIMIT 1'
            );

            if (licenses.isEmpty()) {
                return null;
            }

            SObject pkgLicense = licenses[0];
            String licenseStatus = (String) pkgLicense.get('Status');
            Date expirationDate = (Date) pkgLicense.get('ExpirationDate');

            Boolean isActive = licenseStatus == 'Active';
            Boolean isExpired = !isActive || (expirationDate != null && expirationDate < Date.today());

            if (isExpired) {
                return new LicenseInfo(
                    PLAN_FREE, STATUS_EXPIRED, expirationDate,
                    false, false, null
                );
            }

            // PackageLicense is active — derive plan from Subscription__c
            // (PackageLicense itself doesn't store plan tiers)
            return enrichWithSubscriptionPlan(expirationDate);

        } catch (Exception e) {
            // PackageLicense may not be queryable in all contexts
            // (e.g., unmanaged dev org). Fall through to Subscription__c.
            return null;
        }
    }

    /**
     * Enrich a valid PackageLicense with the plan tier from Subscription__c.
     */
    private static LicenseInfo enrichWithSubscriptionPlan(Date packageExpiry) {
        String orgId = UserInfo.getOrganizationId();

        List<Subscription__c> subs = [
            SELECT Plan__c, Status__c, Expiry_Date__c, Grace_Period_End__c, Package_Version__c
            FROM Subscription__c
            WHERE Org_Id__c = :orgId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String plan = PLAN_STARTER; // Default if no subscription record
        String status = STATUS_ACTIVE;
        String pkgVersion = null;
        Boolean inGrace = false;

        if (!subs.isEmpty()) {
            Subscription__c sub = subs[0];
            plan = mapPlanName(sub.Plan__c);
            status = sub.Status__c;
            pkgVersion = sub.Package_Version__c;
            inGrace = isInGracePeriod(sub);
        }

        Date effectiveExpiry = packageExpiry;
        Boolean isActive = status == STATUS_ACTIVE || status == STATUS_TRIAL;

        return new LicenseInfo(plan, status, effectiveExpiry, isActive, inGrace, pkgVersion);
    }

    /**
     * Resolve license entirely from the Subscription__c record.
     * This is the primary path for dev orgs and orgs without LMA.
     */
    private static LicenseInfo resolveFromSubscription() {
        String orgId = UserInfo.getOrganizationId();

        List<Subscription__c> subs = [
            SELECT Plan__c, Status__c, Expiry_Date__c, Grace_Period_End__c, Package_Version__c
            FROM Subscription__c
            WHERE Org_Id__c = :orgId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (subs.isEmpty()) {
            // No subscription record at all → Free tier
            return new LicenseInfo(
                PLAN_FREE, STATUS_ACTIVE, null,
                true, false, null
            );
        }

        Subscription__c sub = subs[0];
        String plan = mapPlanName(sub.Plan__c);
        String status = sub.Status__c;
        Date expiry = sub.Expiry_Date__c;
        Boolean inGrace = isInGracePeriod(sub);

        // Determine active status
        Boolean isActive = false;
        if (status == STATUS_TRIAL || status == STATUS_ACTIVE || status == 'Past Due') {
            isActive = (expiry == null || expiry >= Date.today());
        }

        // If expired but in grace period, mark as grace
        if (!isActive && inGrace) {
            status = STATUS_GRACE;
        } else if (!isActive && !inGrace) {
            plan = PLAN_FREE; // Hard downgrade
            status = STATUS_EXPIRED;
        }

        return new LicenseInfo(plan, status, expiry, isActive, inGrace, sub.Package_Version__c);
    }

    // ═══════════════════════════════════════════════════════════════
    //  PRIVATE — Helpers
    // ═══════════════════════════════════════════════════════════════

    /**
     * Map plan name variations to canonical constants.
     */
    private static String mapPlanName(String rawPlan) {
        if (String.isBlank(rawPlan)) return PLAN_FREE;
        String normalized = rawPlan.trim().toLowerCase();
        if (normalized == 'enterprise')    return PLAN_ENTERPRISE;
        if (normalized == 'professional' || normalized == 'pro') return PLAN_PRO;
        if (normalized == 'starter')       return PLAN_STARTER;
        return PLAN_FREE;
    }

    /**
     * Determine if the subscription is within its grace period.
     */
    private static Boolean isInGracePeriod(Subscription__c sub) {
        if (sub.Grace_Period_End__c == null) {
            return false;
        }
        return sub.Grace_Period_End__c >= Date.today();
    }

    /**
     * Get the numeric rank of a plan for hierarchy comparison.
     */
    private static Integer getPlanRank(String plan) {
        for (Integer i = 0; i < PLAN_HIERARCHY.size(); i++) {
            if (PLAN_HIERARCHY[i] == plan) {
                return i;
            }
        }
        return 0; // Unknown plans default to Free
    }

    /**
     * Safely detect the managed package namespace.
     */
    private static String getNamespace() {
        try {
            // In a managed package, this class's name will be prefixed
            String className = LicenseService.class.getName();
            if (className.contains('.')) {
                return className.substringBefore('.');
            }
        } catch (Exception e) {
            // Swallow — not in a managed package context
        }
        return null;
    }
}

