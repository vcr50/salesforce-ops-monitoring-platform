# Milestone 45: Command Center UI Hardening + Prototype Alignment

## Milestone 45A — Local Prototype Interactivity
- [x] 1. Update `sentinelflow-dashboard.html` local prototype:
    - [x] Routing: Wire up all sidebar links to dynamic client-side page views.
    - [x] Responsiveness: Add mobile menu toggle and responsive slide-in sidebar drawer.
    - [x] Loading States: Implement pulsing skeleton loading views on page load/refresh.
    - [x] Approvals Table: Implement client-side filtering, sorting, pagination, and badges.
    - [x] Governance Review Modal: Build review popup supporting approve/reject workflows and toast alerts.
    - [x] Incidents Table: Implement client-side filtering (Risk, Status, Env), sorting, and pagination.
    - [x] Timeline: Implement click-to-expand details on events.
    - [x] System Health: Wire live status indicators and thresholds.
    - [x] Accessibility: Add focus outlines and keyboard navigation support.
- [x] 2. Update `sentinelflow-sidebar.html` local prototype:
    - [x] Synchronize visual layout, styles, hover/focus outlines to match unified dashboard.
- [x] 3. Validate prototype interactivity and responsiveness.
- [x] 4. Commit and push 45A prototype-only changes.

## Milestone 45B — Production LWC Alignment Review
- [ ] 1. Review and align Salesforce LWC files (`sentinelFlowBetaAppShell`):
    - [ ] Sidebar active states and mobile collapse.
    - [ ] Focus-visible accessibility outlines.
    - [ ] Page routing and visual consistency.
- [ ] 2. Ensure real Apex-backed approval/action flows are preserved (no simulation in production LWC).
- [ ] 3. Run Apex tests and verify deployment validation.
- [ ] 4. Commit and push 45B LWC changes.
