# Prediction + Auto-Heal Demo Screenshot Checklist

This document catalogs and outlines the visual assets, screenshots, and UI mockups required to support the executive presentation and showcase the business value of SentinelFlow's Prediction and Auto-Heal capabilities.

---

## 1. Purpose
This checklist ensures that sales engineers, presenters, and product managers capture the necessary high-fidelity visual evidence to prove that SentinelFlow's prediction, governance, healing, and ROI tracking capabilities operate exactly as designed.

---

## 2. Dashboard Overview Screenshot
- **Visual Target**: The complete SentinelFlow Command Center console interface.
- **Key Details to Capture**: 
  - The live streaming indicator pulsing in the header.
  - Active incidents grid showing various status lifecycles.
  - Sidebar layout with configuration metrics.
- **Audience Takeaway**: Illustrates the unified, modern, glassmorphic operator console.

---

## 3. Prediction Card Screenshot
- **Visual Target**: The active **Prediction & Anomaly Queue** component.
- **Key Details to Capture**:
  - The warning warning status pill.
  - Plain-text natural language explanation breakdown (e.g. timeout correlations).
  - Operator action buttons: Review Details, Request Approval, Dismiss, Mark Useful, Mark Noisy.
- **Audience Takeaway**: Shows how raw signals are aggregated into clear, explainable warnings.

---

## 4. Guardian Gate Approval Screenshot
- **Visual Target**: The Sentinel Incident detail page in Salesforce.
- **Key Details to Capture**:
  - A risk score $\ge 40.0\%$.
  - `Approval_Status__c` set to `'Pending Approval'`.
  - The locked state indicating that autonomous execution is blocked.
- **Audience Takeaway**: Visual evidence of the Guardian Gate preventing unauthorized changes.

---

## 5. Auto-Heal Execution Result Screenshot
- **Visual Target**: The incident record page after a successful recovery.
- **Key Details to Capture**:
  - `Execution_Status__c` displaying `'Executed'`.
  - `Status__c` displaying `'Action Created'`.
  - The `Created_Case__c` or `Created_Task__c` lookup field pointing to the generated recovery record.
- **Audience Takeaway**: Proves that safe recovery actions successfully trigger and resolve incidents.

---

## 6. Audit Log / Replay Proof Screenshot
- **Visual Target**: The `Sentinel_Audit_Log__c` list view.
- **Key Details to Capture**:
  - The chronological history of logs.
  - Custom decision values: `SUCCESS`, `APPROVAL_REQUIRED`, `BLOCKED_ACTION`, `FAILURE`, `RETRY_EXHAUSTED`.
  - The UUID `Trace_Id__c` field connecting related event logs.
- **Audience Takeaway**: Solid proof for GRC and security auditors of a write-once compliance record.

---

## 7. Cost Savings Widget Screenshot
- **Visual Target**: The **Cost & Value Insights** dashboard panel.
- **Key Details to Capture**:
  - Net Cost Savings (calculated from successful executions).
  - Metrics for Total Hours Saved and Avoided Support Cases.
  - MTTR improvement percentage compared to manual baseline metrics.
- **Audience Takeaway**: Concrete financial proof of SentinelFlow's return on investment (ROI).

---

## 8. Failure Rollback Screenshot
- **Visual Target**: The parent incident record after a simulated failure.
- **Key Details to Capture**:
  - `Execution_Status__c` displaying `'Failed'`.
  - Status reset to `'Approval Required'` and `'Pending Approval'`.
  - Visual proof that no orphaned task or case was committed to the database (reverted by savepoint).
- **Audience Takeaway**: Shows how SentinelFlow fails safely, reverting mutations and returning control to human SREs.

---

## 9. Safety / Governance Screenshot
- **Visual Target**: The `SentinelFlow_Setting__mdt` metadata config list.
- **Key Details to Capture**:
  - Global toggle setting `Auto_Heal_Active` set to `0.0` or `1.0`.
  - Custom hourly rates and MTTR metrics definitions.
- **Audience Takeaway**: Demonstrates the global kill switch capability and policy configuration tools.

---

## 10. Final Demo Asset Checklist

Use the checklist below to verify that all visual assets have been successfully prepared and captured:

- [ ] **Command Center Dashboard** (High-fidelity full console overview)
- [ ] **Critical Prediction Card** (Highlightingexplainability and operator buttons)
- [ ] **Request Approval / Guardian Gate** (Enforcing risk thresholds on incident record)
- [ ] **Approved Auto-Heal Action** (Task/Case lookup linkage on incident)
- [ ] **Created Case / Task Proof** (Showing the generated Task/Case record detail pages)
- [ ] **Audit Timeline** (`Sentinel_Audit_Log__c` record list proving UUID tracing)
- [ ] **Rollback / Failure Handling** (Parent status reset to triage state, empty database checks)
- [ ] **Estimated Value Realization Widgets** (Dashboard ROI analytics widgets metrics)
