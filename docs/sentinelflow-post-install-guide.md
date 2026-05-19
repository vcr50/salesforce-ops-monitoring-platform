# SentinelFlow — Post-Install Configuration Guide

> **Package**: SentinelFlow v2.6  
> **Publisher**: TomcodeX  
> **Last updated**: 2026-05-12

---

## 1. Overview

After installing the SentinelFlow managed package from AppExchange, complete the steps below to connect your Salesforce org to the SentinelFlow Intelligence Backend. This enables AI classification, operational memory, auto-heal orchestration, and predictive analytics.

---

## 2. Permission Set Assignment

The package install handler automatically assigns **SentinelFlow_Admin** to the installing user. For additional users:

| Permission Set | Audience | Access Level |
|---|---|---|
| `SentinelFlow_Admin` | Org administrators | Full CRUD on all SentinelFlow objects, triggers, and Named Credentials |
| `SentinelFlow_Operator` | DevOps / SRE engineers | Create and edit incidents, trigger heals — no delete access |
| `SentinelFlow_Viewer` | Executives / Stakeholders | Read-only access to incidents, memory, runbooks, and predictions |

**To assign**:
1. Navigate to **Setup → Permission Sets**.
2. Select the desired permission set.
3. Click **Manage Assignments → Add Assignment**.
4. Select the target users and save.

---

## 3. Named Credential Configuration

SentinelFlow uses a **Named Credential** (`SentinelFlow_Backend`) to securely connect Apex callouts to the backend intelligence API. The package ships with a pre-configured Named Credential pointing to the hosted backend.

### Default Configuration (Hosted Backend)

The package includes a pre-configured Named Credential:

| Property | Value |
|---|---|
| Label | `SentinelFlow Backend` |
| URL | `https://sentinelflow.onrender.com` |
| Authentication | Anonymous (NoAuthentication) |
| Type | Legacy |

> [!NOTE]
> This default configuration connects to the TomcodeX-hosted SentinelFlow backend. No additional setup is required for standard usage.

### Custom Backend (Self-Hosted)

If your organisation hosts its own SentinelFlow API backend:

1. Navigate to **Setup → Named Credentials**.
2. Click on **SentinelFlow Backend**.
3. Click **Edit**.
4. Update the **URL** field to your self-hosted backend endpoint (e.g., `https://sentinelflow-api.yourcompany.com`).
5. Save.

> [!IMPORTANT]
> Your self-hosted backend must expose the same API surface as the hosted version. See `docs/api.md` for the full endpoint specification.

---

## 4. External Credential Setup (Enhanced Security)

For organisations requiring authenticated API access, you can upgrade from the Legacy Named Credential to an **External Credential** with a **Custom Header** principal.

### Step-by-Step

1. **Create an External Credential**:
   - Navigate to **Setup → External Credentials**.
   - Click **New**.
   - Label: `SentinelFlow_Backend_Credential`
   - Authentication Protocol: **Custom**

2. **Create a Principal**:
   - Under the External Credential, click **New** under Principals.
   - Parameter Name: `X-SF-Tenant-Id`
   - Parameter Value: Your Salesforce Org ID (`UserInfo.getOrganizationId()`)
   - Add any additional API key headers as needed.

3. **Create a Named Credential (Enhanced)**:
   - Navigate to **Setup → Named Credentials**.
   - Click **New**.
   - Label: `SentinelFlow Backend`
   - URL: `https://sentinelflow.onrender.com`
   - External Credential: select `SentinelFlow_Backend_Credential`

4. **Grant Principal Access**:
   - Navigate to **Setup → Permission Sets → SentinelFlow_Admin**.
   - Under **External Credential Principal Access**, add the principal created above.
   - Repeat for `SentinelFlow_Operator`.

> [!WARNING]
> After switching to an External Credential, the old Legacy Named Credential entry must be removed to avoid conflicts. Ensure all Apex callouts still reference `callout:SentinelFlow_Backend`.

---

## 5. Platform Event Subscriptions

SentinelFlow uses three Platform Events for real-time event-driven processing:

| Platform Event | Purpose |
|---|---|
| `SentinelFlow_Incident__e` | Triggers incident creation and AI classification |
| `SentinelFlow_Alert__e` | Sends alert notifications |
| `SentinelFlow_Heal_Command__e` | Orchestrates auto-heal actions |

These are automatically active after installation. No additional configuration is needed.

---

## 6. Custom Metadata Configuration

SentinelFlow ships with configurable thresholds and rules via Custom Metadata Types. Admins can tune these without code changes:

### Detection Thresholds (`SF_Detection_Threshold__mdt`)

| Record | Default | Purpose |
|---|---|---|
| `API_Latency` | Configurable | Latency threshold before incident detection |
| `Integration_Errors` | Configurable | Error count threshold before escalation |

### Healing Rules (`SF_Healing_Rule__mdt`)

| Record | Purpose |
|---|---|
| `OAuth_Refresh` | Auto-refresh expired OAuth tokens |
| `Pause_Batch` | Pause batch jobs when governor limits are at risk |
| `Requeue_Job` | Requeue failed scheduled/queueable jobs |
| `Retry_With_Backoff` | Retry failed API calls with exponential backoff |

### Integration Configs (`SF_Integration_Config__mdt`)

| Record | Purpose |
|---|---|
| `HubSpot_Sync` | HubSpot integration settings |
| `Stripe_Gateway` | Stripe payment gateway settings |

**To configure**: Navigate to **Setup → Custom Metadata Types → Manage Records**.

---

## 7. Verification Checklist

After completing the setup, verify the following:

- [ ] **Permission Sets**: At least one admin has `SentinelFlow_Admin` assigned.
- [ ] **Named Credential**: `SentinelFlow_Backend` is reachable — test by opening the Developer Console and running:
  ```apex
  HttpRequest req = new HttpRequest();
  req.setEndpoint('callout:SentinelFlow_Backend/api/health');
  req.setMethod('GET');
  HttpResponse res = new Http().send(req);
  System.debug(res.getBody());
  // Expected: {"status":"ok","version":"2.0.0","intelligenceMode":"self-evolving"}
  ```
- [ ] **Smoke Test**: Create a test `Integration_Log__c` record with `Status__c = 'Failed'`. Verify that the trigger chain fires:
  ```
  Integration_Log__c → IntegrationLogTrigger → SentinelFlow_Incident__e → SF_Incident__c
  ```
- [ ] **SentinelFlow Console**: Open the **SentinelFlow Console** Lightning App from the App Launcher and verify the Command Center loads with KPI cards and the incident chart.

---

## 8. Troubleshooting

| Issue | Resolution |
|---|---|
| `System.CalloutException: Unauthorized endpoint` | Ensure `SentinelFlow_Backend` Named Credential exists in Setup. Verify the URL is correct. |
| Permission errors on SentinelFlow objects | Assign the appropriate permission set (`Admin`, `Operator`, or `Viewer`) to the user. |
| No incidents appearing | Verify `IntegrationLogTrigger` is active. Check that `Integration_Log__c` records have `Status__c = 'Failed'`. |
| Circuit breaker OPEN on heal actions | The backend has blocked heal retries after repeated failures. Wait for the cooldown period or check `GET /api/heal/status` for details. |

---

## 9. Support

- **Documentation**: [SentinelFlow Docs](https://sentinelflow.tomcodex.com/docs)
- **Support Email**: support@tomcodex.com
- **AppExchange Listing**: [SentinelFlow on AppExchange](https://appexchange.salesforce.com)
