# Prediction + Auto-Heal Demo QA Checklist

This document provides a pre-demo quality assurance (QA) validation checklist to verify environment, assets, scripts, data, and safety controls before presenting to customers and stakeholders.

---

## 1. Purpose
The purpose of this checklist is to guarantee a flawless, high-fidelity demo execution by verifying that all technical configurations, visual assets, speaking materials, and safety boundaries are fully prepared and active.

---

## 2. Demo Environment Readiness
- [ ] Verify target org is active and accessible: `vjdev@asap.com`.
- [ ] Confirm latest codebase is compiled and deployed to the org with zero compilation errors.
- [ ] Verify that all 420 unit tests pass org-wide.
- [ ] Check custom setting override `Auto_Heal_Active` is set to `1.0` (Active).

---

## 3. Screenshot / Asset Readiness
- [ ] Validate high-fidelity screenshots are captured according to [`docs/prediction-auto-heal-demo-screenshot-checklist.md`](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/prediction-auto-heal-demo-screenshot-checklist.md).
- [ ] Confirm image files are placed in the release documentation folder.
- [ ] Verify diagram paths and markdown embeddings resolve successfully.

---

## 4. Prediction Card Validation
- [ ] Execute mock anomaly telemetry signals using simulation scripts.
- [ ] Verify the warning card generates on the Command Center LWC dashboard.
- [ ] Confirm natural language explanation translates timeout/deployment patterns correctly.
- [ ] Test LWC action buttons: verify "Request Approval" and "Dismiss" trigger Apex services cleanly.

---

## 5. Guardian Gate Validation
- [ ] Verify an incident with a risk score $\ge 40\%$ enforces `'Pending Approval'` status.
- [ ] Test the execution block: assert that execution is rejected and throws `AutoHealException` when unapproved.
- [ ] Confirm manual approval transition updates state to `'Approved'` and releases the execution gate.

---

## 6. Auto-Heal Execution Validation
- [ ] Execute low-risk script `auto_heal_pilot_scenario_a.apex` and confirm Task creation.
- [ ] Execute medium-risk script `auto_heal_pilot_scenario_b.apex` and confirm Case creation.
- [ ] Check that lookup relationship fields point directly to generated Tasks and Cases.

---

## 7. Rollback / Failure Demo Validation
- [ ] Run failure-inducing action `TEST_FORCE_FAILURE`.
- [ ] Confirm DML rollback occurs, leaving no orphaned tasks/cases in database.
- [ ] Confirm parent incident status fields successfully reset to triage state (`Failed` / `Approval Required` / `Pending Approval`).
- [ ] Confirm Slack / MS Teams webhook notification payload is scheduled asynchronously.

---

## 8. Audit Log Validation
- [ ] Open `Sentinel_Audit_Log__c` list view.
- [ ] Confirm audit log matches the scenario execution decision history: `SUCCESS`, `APPROVAL_REQUIRED`, `BLOCKED_ACTION`, `FAILURE`, `RETRY_EXHAUSTED`.
- [ ] Verify UUID Trace ID matches across related logs.
- [ ] Verify referential integrity fallback logs the event details when lookup reference is missing.

---

## 9. Cost Savings Widget Validation
- [ ] Confirm that successful executions calculate metrics on dashboard metric cards.
- [ ] Verify baseline variables (Engineering Hourly Rate, Case Cost, MTTR limits) reference `SentinelFlow_Setting__mdt`.
- [ ] Check glassmorphic widget displays totals for cost savings, MTTR improvements, hours saved, and cases avoided.

---

## 10. Speaker Script Readiness
- [ ] Review the speaking script in [`docs/prediction-auto-heal-executive-demo-script.md`](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/prediction-auto-heal-executive-demo-script.md).
- [ ] Verify slide transitions align with speaking parts.
- [ ] Confirm standard pitches ("reactive firefighting to predictive, governed operations") and safety hierarchies are memorized.

---

## 11. Q&A Readiness
- [ ] Review objection handling talk tracks in [`docs/prediction-auto-heal-demo-objection-handling.md`](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/prediction-auto-heal-demo-objection-handling.md).
- [ ] Practice explaining false prediction corrections, retry limits checks, and platform CPU headroom limits.

---

## 12. Final Go / No-Go Checklist

| Target Item | Checked Condition | Passed? |
|---|---|---|
| Target Org | Vjdev@asap.com is up and active | [ ] |
| Security | Dangerous actions strictly blocked | [ ] |
| Rollback | Atomic Savepoint rollbacks working | [ ] |
| Throttling | Retry limits capped at 3 attempts | [ ] |
| Compliance | Audit Logs trace ID tracking verified | [ ] |
| Analytics | Cost savings metrics calculate correctly | [ ] |
| Script | Speaker script and Q&A prep complete | [ ] |

**Overall Readiness Status**: **Ready for Presentation**
