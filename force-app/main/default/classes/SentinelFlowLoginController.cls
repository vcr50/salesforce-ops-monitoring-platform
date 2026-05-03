/**
 * @description Apex controller for the SentinelFlow custom login page.
 *              Handles username/password login and forgot-password flows
 *              for the Experience Cloud site.
 */
public without sharing class SentinelFlowLoginController {
    @TestVisible
    private static final String SENTINEL_FLOW_LIGHTNING_APP_URL =
        'https://astrosoft2-dev-ed.develop.lightning.force.com/lightning/n/Sentinel_Flow';

    /**
     * @description Authenticates a user with username + password and returns
     *              the redirect URL on success.
     * @param username The user's Salesforce username or community email
     * @param password The user's password
     * @param startUrl Optional start URL to redirect to after login
     * @return The page URL to redirect to (null on failure)
     */
    @AuraEnabled
    public static String loginUser(String username, String password, String startUrl) {
        try {
            ApexPages.PageReference pageRef = Site.login(
                username,
                password,
                String.isBlank(startUrl) ? null : startUrl
            );
            if (pageRef != null) {
                return SENTINEL_FLOW_LIGHTNING_APP_URL;
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Login failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String normalizeLoginRedirect(String redirectUrl) {
        if (String.isBlank(redirectUrl)) {
            return getNetworkHomeUrl();
        }

        String homeUrl = getNetworkHomeUrl();
        String siteRootPath = getSiteRootPath(homeUrl);

        if (redirectUrl == '/s' || redirectUrl.startsWith('/s/')) {
            return siteRootPath + redirectUrl.substring(1);
        }
        if (redirectUrl == '/') {
            return siteRootPath;
        }

        return redirectUrl;
    }

    @TestVisible
    private static String getNetworkHomeUrl() {
        String networkId = Network.getNetworkId();
        if (String.isNotBlank(networkId)) {
            return buildHomeUrl(Network.getLoginUrl(networkId));
        }

        return '/SentinelFlow/';
    }

    @TestVisible
    private static String buildHomeUrl(String loginUrl) {
        if (String.isNotBlank(loginUrl) && loginUrl.endsWith('/login')) {
            return loginUrl.removeEnd('/login') + '/';
        }

        return '/SentinelFlow/';
    }

    @TestVisible
    private static String getSiteRootPath(String homeUrl) {
        if (String.isBlank(homeUrl)) {
            return '/SentinelFlow/';
        }

        if (homeUrl.startsWith('/')) {
            return homeUrl.endsWith('/') ? homeUrl : homeUrl + '/';
        }

        Url parsedUrl = new Url(homeUrl);
        String path = parsedUrl.getPath();
        return String.isBlank(path) ? '/' : (path.endsWith('/') ? path : path + '/');
    }

    /**
     * @description Sends a password-reset email for the given username or email.
     * @param usernameOrEmail The user's Salesforce username or community email
     * @return true if the reset email was queued successfully
     */
    @AuraEnabled
    public static Boolean forgotPassword(String usernameOrEmail) {
        try {
            // First, try to find an active user by Username
            List<User> users = [SELECT Username FROM User WHERE Username = :usernameOrEmail AND IsActive = true LIMIT 1];
            
            // If not found, try to find by Email
            if (users.isEmpty()) {
                users = [SELECT Username FROM User WHERE Email = :usernameOrEmail AND IsActive = true LIMIT 1];
            }
            
            if (!users.isEmpty()) {
                return Site.forgotPassword(users[0].Username);
            }
            
            // Return true to prevent enumeration attacks if no user is found
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to process request: ' + e.getMessage());
        }
    }

    /**
     * @description Fetches enabled SSO login URLs for external identity providers.
     *              For a single Developer Edition org this intentionally returns
     *              no links, because a Salesforce auth provider pointing back to
     *              the same org fails with SAME_ORG_SSO.
     * @return Map of AuthProvider DeveloperName to its SSO URL.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getSsoUrls() {
        return new Map<String, String>();
    }
}
