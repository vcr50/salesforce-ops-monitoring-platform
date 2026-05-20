/**
 * LicenseCacheService
 * Provides a transaction-level and Platform Cache layer for license resolution.
 *
 * Reduces SOQL queries on hot paths (dashboard loads, REST API calls)
 * by caching the resolved LicenseInfo for the duration of a transaction
 * and optionally in a Platform Cache org partition.
 *
 * @author  Tomcodex
 * @version 2.7
 */
public with sharing class LicenseCacheService {

    private static final String CACHE_PARTITION = 'local.SentinelFlow';
    private static final String CACHE_KEY = 'LicenseInfo';
    private static final Integer CACHE_TTL_SECONDS = 3600; // 1 hour

    /**
     * Resolve license info with Platform Cache support.
     * Falls back to direct resolution if cache is unavailable.
     */
    public static LicenseService.LicenseInfo resolveWithCache() {
        // 1. Try Platform Cache
        LicenseService.LicenseInfo cached = getFromPlatformCache();
        if (cached != null) {
            return cached;
        }

        // 2. Resolve fresh
        LicenseService.LicenseInfo fresh = LicenseService.resolve();

        // 3. Store in Platform Cache
        putInPlatformCache(fresh);

        return fresh;
    }

    /**
     * Invalidate all cached license data.
     * Call this after subscription changes (upgrade, downgrade, expiry).
     */
    public static void invalidate() {
        LicenseService.clearCache();
        removePlatformCache();
    }

    /**
     * Check if Platform Cache is available in this org.
     */
    public static Boolean isPlatformCacheAvailable() {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            return partition != null;
        } catch (Exception e) {
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  PRIVATE — Platform Cache Operations
    // ═══════════════════════════════════════════════════════════════

    private static LicenseService.LicenseInfo getFromPlatformCache() {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            Object cached = partition.get(CACHE_KEY);
            if (cached instanceof Map<String, Object>) {
                return deserializeLicenseInfo((Map<String, Object>) cached);
            }
        } catch (Exception e) {
            // Cache not configured or not available — silent fallback
        }
        return null;
    }

    private static void putInPlatformCache(LicenseService.LicenseInfo info) {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            Map<String, Object> serialized = serializeLicenseInfo(info);
            partition.put(CACHE_KEY, serialized, CACHE_TTL_SECONDS);
        } catch (Exception e) {
            // Cache not configured — non-blocking
        }
    }

    private static void removePlatformCache() {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            partition.remove(CACHE_KEY);
        } catch (Exception e) {
            // Silent fallback
        }
    }

    /**
     * Serialize LicenseInfo to a cache-safe Map.
     */
    private static Map<String, Object> serializeLicenseInfo(LicenseService.LicenseInfo info) {
        return new Map<String, Object>{
            'plan' => info.plan,
            'status' => info.status,
            'expiryDate' => info.expiryDate != null ? String.valueOf(info.expiryDate) : null,
            'isActive' => info.isActive,
            'inGracePeriod' => info.inGracePeriod,
            'packageVersion' => info.packageVersion
        };
    }

    /**
     * Deserialize a cached Map back to LicenseInfo.
     */
    private static LicenseService.LicenseInfo deserializeLicenseInfo(Map<String, Object> data) {
        Date expiry = null;
        if (data.get('expiryDate') != null) {
            expiry = Date.valueOf((String) data.get('expiryDate'));
        }
        return new LicenseService.LicenseInfo(
            (String) data.get('plan'),
            (String) data.get('status'),
            expiry,
            (Boolean) data.get('isActive'),
            (Boolean) data.get('inGracePeriod'),
            (String) data.get('packageVersion')
        );
    }
}

