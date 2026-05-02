/**
 * @description Apex controller for the SentinelFlow custom login page.
 *              Handles username/password login and forgot-password flows
 *              for the Experience Cloud site.
 */
public without sharing class SentinelFlowLoginController {

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
            ApexPages.PageReference pageRef = Site.login(username, password, startUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Login failed: ' + e.getMessage());
        }
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
     * @description Fetches SSO login URLs for Salesforce and Google Auth Providers.
     * @return Map of AuthProvider DeveloperName to its SSO URL.
     */
    @AuraEnabled
    public static Map<String, String> getSsoUrls() {
        Map<String, String> urls = new Map<String, String>();
        String networkId = Network.getNetworkId();
        if (networkId == null) return urls;

        for (AuthProvider ap : [SELECT Id, DeveloperName, FriendlyName FROM AuthProvider WHERE DeveloperName IN ('Salesforce', 'Google')]) {
            String ssoUrl = Auth.AuthConfiguration.getAuthProviderSsoUrl(networkId, '/s/', ap.DeveloperName);
            urls.put(ap.DeveloperName, ssoUrl);
        }
        return urls;
    }
}
