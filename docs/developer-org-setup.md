# SentinelFlow Developer Org Setup

This project is designed to work with a single Salesforce Developer Edition org.

## What You Need

- A Salesforce Developer Edition org
- A Connected App in that org
- Local Node.js and npm
- Optional local PostgreSQL and Redis for later phases

## Connected App Setup

1. Open Salesforce Setup.
2. Go to `App Manager`.
3. Create a `Connected App`.
4. Enable OAuth settings.
5. Set the callback URL to `http://localhost:3000/auth/callback`.
6. Add the scopes needed for API access and refresh tokens.
7. Copy the client ID and client secret into `.env`.

## Experience Cloud Access

The SentinelFlow Digital Experience site no longer uses a separate custom login page. Internal Salesforce users can open the site directly while logged into the org.

For the developer org, use:

- Site home: `https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/`
- Internal Lightning app: `https://astrosoft2-dev-ed.develop.lightning.force.com/lightning/n/SentinelFlow_Home`

`allowInternalUserLogin` is enabled on the SentinelFlow network, so admins and internal users should not need a separate portal username/password for day-to-day development.

If you still need an external community user for testing, create one with:

```bash
sf apex run --file scripts/apex/createPortalLoginUser.apex --target-org astrosoft2-dev-ed
sf apex run --file scripts/apex/resetPassword.apex --target-org astrosoft2-dev-ed
```

## Local Environment

Use the values in `.env.example` as the baseline:

- `APP_ENV=developer-org`
- `SALESFORCE_INSTANCE_URL=https://login.salesforce.com`
- `SALESFORCE_ORG_ALIAS=sentinelFlow-dev-edition`

## Suggested Local Workflow

1. Start with one Developer Org as the system of record.
2. Use custom objects like `Incident__c` and `Integration_Log__c` in that org.
3. Store Salesforce metadata in `force-app/main/default/` using Salesforce DX source format.
4. Use `manifest/package.xml` when retrieving or deploying the SentinelFlow metadata set.
5. Run the Node.js app locally for middleware and API testing.
6. Add local PostgreSQL and Redis only when you begin Phase 2 event persistence work.

## Standard Salesforce Folders In This Repo

- `force-app/main/default/objects/`: custom objects and fields
- `force-app/main/default/classes/`: Apex classes and tests
- `force-app/main/default/triggers/`: Apex triggers
- `force-app/main/default/lwc/`: Lightning Web Components
- `force-app/main/default/permissionsets/`: permission sets
- `force-app/main/default/layouts/`: page layouts
- `force-app/main/default/tabs/`: custom tabs
- `force-app/main/default/flexipages/`: Lightning pages

## Notes

- Multi-org support can stay in the design, but the actual implementation can begin with a single-org configuration.
- Heroku and Terraform can remain documentation-level concerns until you are ready to demonstrate cloud deployment.
