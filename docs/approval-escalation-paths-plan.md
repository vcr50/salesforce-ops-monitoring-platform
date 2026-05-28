# Milestone 43F: Approval Escalation Paths Plan

## 1. Purpose
To ensure incidents do not stall in the "Approval Required" state indefinitely. SentinelFlow will identify overdue approvals and clearly highlight them in the dashboard so that the next designated owner or manager can intervene.

## 2. Customer Need
When critical or high-risk incidents require human approval, delays in response can lead to prolonged system outages or unmitigated security risks. Identifying stalled approvals is crucial for operational efficiency.

## 3. Scope
- **Threshold Definition**: Define an "overdue" timeframe (e.g., older than 4 hours). For the initial v1.1.0 release, this can be hardcoded or dynamically calculated based on Incident creation time vs. current time.
- **Escalation Status**: Use a calculated field or a client-side evaluation to determine if an incident's approval is "Overdue".
- **Visual Indicators**: 
  - Add an "Escalation Needed" badge or warning icon on incidents listed in the Clearance Queue.
  - Display escalation reason text indicating how long the incident has been waiting.
- **Out of Scope**: 
  - No active notifications (Slack/Email) for escalations in this milestone.
  - No automatic reassignment of ownership.

## 4. Implementation Details
### Backend (Apex)
- Update `ZentomDashboardController.cls` (specifically `getPendingApprovalRows`).
- Introduce an `isEscalated` boolean or `escalationStatus` string in the `IncidentRow` wrapper.
- Calculate escalation based on the `CreatedDate` (e.g., if `Approval_Status__c == 'Pending Approval'` and `CreatedDate` is more than 4 hours ago, mark as escalated).

### Frontend (LWC)
- Update `zentomDashboard.html` inside the Clearance Queue section to conditionally display an Escalation badge (e.g., `<span class="badge warning-badge">Escalation Needed</span>`) if the incident is escalated.
- Update `zentomDashboard.js` to handle any specific CSS class generation or text formatting for the escalation indicator.

## 5. Validation Checklist
- [ ] Ensure the Apex method correctly identifies older incidents as requiring escalation.
- [ ] Ensure the LWC Clearance Queue visually highlights the escalated incidents without breaking the layout.
- [ ] Run `sf project deploy validate` with Apex tests.
