# SentinelFlow Portal Login Troubleshooting Guide

## Issue: "Insufficient Privileges" Error

When logging into the SentinelFlow Experience Cloud portal, users receive an "Insufficient Privileges" error message.

## Fastest Developer Org Option

Skip SSO for the Developer Edition org. Same-org Salesforce SSO fails with `SAME_ORG_SSO`, and placeholder Google credentials will also fail. Use the custom username/password form:

- URL: `https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login`
- Username: `sentinelflow.portal.00ddl0000053505uaa@example.com`
- Password: `SentinelFlow#2026May!`

Reset the known developer password if needed:

```bash
sf apex run --file scripts/apex/resetPassword.apex --target-org sentinelFlow-dev-edition
```

Create or repair the portal user if needed:

```bash
sf apex run --file scripts/apex/createPortalLoginUser.apex --target-org sentinelFlow-dev-edition
```

## Root Causes and Solutions

### 1. Permission Set Assignment Not Applied

**Problem**: The `SentinelFlow_Portal_Viewer` permission set exists but is not assigned to the portal user.

**Solution**:
1. Go to Salesforce Setup
2. Search for "Permission Set Assignments"
3. Find `SentinelFlow_Portal_Viewer`
4. Click "Add Assignments"
5. Search for and select the portal user: `sentinelflow.portal.00ddl0000053505uaa@example.com`
6. Click "Assign"

### 2. Site Guest User Profile Permissions

**Problem**: The Experience Cloud site's guest user profile doesn't have sufficient permissions.

**Solution**:
1. Go to Salesforce Setup
2. Search for "All Sites"
3. Click on the SentinelFlow site
4. Click "Workspaces" > "Administration" > "Login & Registration"
5. Ensure the portal user profile is correctly configured
6. Check "Public Access Settings" to verify the guest user profile has necessary permissions

### 3. Sharing Settings for Custom Objects

**Problem**: The custom objects (Incident__c, Integration_Log__c, etc.) have sharing settings that prevent portal access.

**Solution**:
1. Go to Salesforce Setup
2. Search for "Sharing Settings"
3. For each custom object:
   - Incident__c
   - Integration_Log__c
   - Environment__c
   - Deployment_Record__c
   - SLA_Policy__c
4. Set the organization-wide defaults to "Public Read Only" or "Read/Write"
5. Create sharing rules if needed for more granular access

### 4. Profile Access Missing

**Problem**: The portal user's profile doesn't have access to the required objects or fields.

**Solution**:
1. Go to Salesforce Setup
2. Search for "Profiles"
3. Find the profile assigned to the portal user
4. Edit the profile and ensure:
   - Object permissions are enabled for all SentinelFlow custom objects
   - Field permissions are enabled for required fields
   - Tab visibility is set to "Default On" for relevant tabs

### 5. Experience Cloud Site Navigation Configuration

**Problem**: The site navigation points to pages or components the user doesn't have access to.

**Solution**:
1. Go to Salesforce Setup
2. Search for "All Sites"
3. Click on the SentinelFlow site
4. Click "Builder" to open Experience Builder
5. Review the navigation menu
6. Ensure all linked pages are accessible to portal users
7. Check page-level permissions and component access

### 6. Session Settings

**Problem**: Session timeout or security settings are preventing access.

**Solution**:
1. Go to Salesforce Setup
2. Search for "Session Settings"
3. Review and adjust:
   - Session timeout duration
   - Lockout sessions
   - Cache and cookie settings
4. For Experience Cloud, check "Session Security Levels"

## Verification Steps

After applying fixes, verify the login works:

1. Clear browser cache and cookies
2. Navigate to: https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login
3. Log in with:
   - Username: sentinelflow.portal.00ddl0000053505uaa@example.com
   - Password: SentinelFlow#2026May!
4. Verify you can access:
   - Home page
   - Incidents page
   - Integrations page
   - Analytics page

## Common Mistakes to Avoid

1. **Not assigning permission sets**: Creating permission sets but forgetting to assign them to users
2. **Ignoring sharing settings**: Setting object permissions but not configuring organization-wide sharing
3. **Profile conflicts**: Assigning a permission set but the base profile denies access
4. **Site configuration errors**: Not properly configuring the Experience Cloud site's public access settings

## Additional Resources

- [Salesforce Experience Cloud Documentation](https://help.salesforce.com/s/articleView?id=sf.communities_admin_login_access.htm)
- [Permission Sets Overview](https://help.salesforce.com/s/articleView?id=sf.perm_sets_overview.htm)
- [Sharing Settings](https://help.salesforce.com/s/articleView?id=sf_sharing_object_access.htm)

## Quick Fix Checklist

- [ ] Permission set assigned to portal user
- [ ] Profile has object and field access
- [ ] Sharing settings configured for custom objects
- [ ] Site navigation properly configured
- [ ] Session settings reviewed
- [ ] Browser cache cleared
- [ ] Login tested successfully
