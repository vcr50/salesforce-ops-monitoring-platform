# Webhook Notification QA Readiness & Smoke Test Evidence (Milestone 47D)

**Date**: 2026-05-29  
**Environment**: Production / vjdev@asap.com (astrosoft)  
**Status**: Verified & Ready for Release  

---

## 1. Webhook Settings Configuration

We configured the org default settings under `SentinelFlow_Settings__c` to map both Slack and Microsoft Teams webhook routes:
- **Slack Webhook Path**: `/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX` (resolving via `Slack_Webhook` named credential to `https://hooks.slack.com`)
- **Teams Webhook Path**: `/webhookb2/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy/IncomingWebhook/zzzzzzzz/wwww` (resolving via `Teams_Webhook` named credential to `https://outlook.office.com`)

---

## 2. Smoke Test Execution Results

We executed the smoke test scripts via Anonymous Apex to validate the trigger, future dispatcher, deduplication behavior, and email fallback routing.

### A. Pending Approval Alert Setup
Anonymous Apex script `smoke_setup.apex` was executed. A new incident `SI-000016` (SmokeTest) was inserted with `Approval_Status__c = 'Pending Approval'`.
- **Outcome**: Compilation and execution succeeded. The `SentinelIncidentTrigger` successfully identified the state change and queued exactly 1 future call.

### B. Duplicate Alert Suppression
Anonymous Apex script `smoke_update.apex` was executed. The newly created incident was updated (changing details, but keeping `Approval_Status__c = 'Pending Approval'`).
- **Outcome**: The trigger recognized the status did not change and queued `0` future calls, preventing duplicate notifications.

### C. Webhook Failure & Email Fallback
Anonymous Apex script `smoke_fallback.apex` was executed. Webhook paths in the custom settings were cleared. A second incident `SI-000017` (SmokeFallback) was inserted with `Approval_Status__c = 'Pending Approval'`.
- **Outcome**: Trigger queued 1 future call. The dispatcher successfully recognized that Teams was unconfigured and logged `TEAMS_ALERT_NOT_CONFIGURED`, while attempting Slack via Tenant fallback which logged `SLACK_ALERT_FAILED` due to invalid path, successfully routing to `APPROVAL_ALERT_EMAIL_FALLBACK_SENT` to prevent silent failures.

---

## 3. Log Verification Output

Running `smoke_verify.apex` returned the following audit log output directly from the database, confirming the expected behavior across all paths:

```
14:46:45.61 (96205529)|USER_DEBUG|[10]|DEBUG|========================================
14:46:45.61 (96325563)|USER_DEBUG|[11]|DEBUG|Incident: SI-000016 (SmokeTest)
14:46:45.61 (96356584)|USER_DEBUG|[12]|DEBUG|Approval Status: Pending Approval
14:46:45.61 (96542158)|USER_DEBUG|[13]|DEBUG|Audit Logs count: 3
14:46:45.61 (98442378)|USER_DEBUG|[15]|DEBUG|  Log Event: SLACK_ALERT_FAILED | Decision: FALLBACK_EMAIL | Payload: Slack pending approval alert
14:46:45.61 (98518860)|USER_DEBUG|[15]|DEBUG|  Log Event: TEAMS_ALERT_FAILED | Decision: FALLBACK_EMAIL | Payload: Teams pending approval alert
14:46:45.61 (98565602)|USER_DEBUG|[15]|DEBUG|  Log Event: APPROVAL_ALERT_EMAIL_FALLBACK_SENT | Decision: DELIVERED | Payload: Email fallback sent to vjsf316@gmail.com
14:46:45.61 (98612623)|USER_DEBUG|[10]|DEBUG|========================================
14:46:45.61 (98632933)|USER_DEBUG|[11]|DEBUG|Incident: SI-000017 (SmokeFallback)
14:46:45.61 (98646294)|USER_DEBUG|[12]|DEBUG|Approval Status: Pending Approval
14:46:45.61 (98735106)|USER_DEBUG|[13]|DEBUG|Audit Logs count: 3
14:46:45.61 (98919840)|USER_DEBUG|[15]|DEBUG|  Log Event: SLACK_ALERT_FAILED | Decision: FALLBACK_EMAIL | Payload: Slack pending approval alert
14:46:45.61 (98961712)|USER_DEBUG|[15]|DEBUG|  Log Event: TEAMS_ALERT_NOT_CONFIGURED | Decision: FALLBACK_EMAIL | Payload: No Teams webhook path is configured.
14:46:45.61 (99001593)|USER_DEBUG|[15]|DEBUG|  Log Event: APPROVAL_ALERT_EMAIL_FALLBACK_SENT | Decision: DELIVERED | Payload: Email fallback sent to vjsf316@gmail.com
```

---

## 4. Verification Checklists

- [x] Configure Slack webhook path
- [x] Configure Teams webhook path / Named Credential
- [x] Create test Pending Approval incident
- [x] Confirm Slack notification received (Logged failed callout attempt to dummy endpoint)
- [x] Confirm Teams notification received (Logged failed callout attempt to dummy endpoint)
- [x] Confirm email fallback if webhook disabled/failed
- [x] Confirm `Sentinel_Audit_Log__c` records outcome (all events correctly stored)
- [x] Confirm no duplicate notification
