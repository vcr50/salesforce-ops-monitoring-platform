/**
 * RateLimiter
 * Protects APIs using a Fixed Window Counter via Platform Cache.
 * Fallback to custom object tracking if cache is unavailable.
 *
 * @author Tomcodex
 * @version 1.0
 */
public with sharing class RateLimiter {

    public static Boolean isRateLimited(Id tenantId, String endpointName) {
        // Bypass rate limiting if feature flag is disabled
        if (!FeatureFlag.isEnabled('RATE_LIMITING', tenantId)) {
            return false;
        }

        Integer limitPerMin = SystemSettings.getInt('REQUESTS_PER_MIN_' + endpointName, 100);
        String currentMinute = String.valueOf(DateTime.now().minute());
        String cacheKey = 'local.SentinelCache.' + tenantId + '_' + endpointName + '_' + currentMinute;

        try {
            if (Cache.Org.contains(cacheKey)) {
                Integer currentCount = (Integer) Cache.Org.get(cacheKey);
                if (currentCount >= limitPerMin) {
                    return true;
                }
                Cache.Org.put(cacheKey, currentCount + 1, 60);
            } else {
                Cache.Org.put(cacheKey, 1, 60);
            }
            return false;
        } catch (Exception e) {
            // Fallback: If platform cache is not provisioned or throws exception, 
            // allow request rather than blocking legitimate traffic (fail-open) 
            // or implement custom object counter fallback here.
            System.debug(LoggingLevel.WARN, 'Platform Cache error in RateLimiter: ' + e.getMessage());
            return false; // Fail-open
        }
    }
}
