# SentinelFlow Maintenance Log

## Active Milestones

### Milestone 43A & 43B — Native Approval & Action Center Queues: Complete
- Replaced mock integrations with native SOQL and DML for Sentinel_Incident__c.
- Implemented Guardian Gate (Approvals) and Execution Gate (Action Center).
- Linked Case creation and Sentinel_Audit_Log__c / Zentom_Policy_Decision__c to executions.
- Safely deployed and tested.

### Milestone 43C — Dashboard Filter UX Improvements: Complete
- Unified Time Range, Risk, Status, Environment, Type, and AI Confidence filters into a responsive `.filters-container`.
- Introduced macro "Preset Views" to automatically apply filter combinations.
- Updated Apex wrapper class (`IncidentRow`) and backend queries to fetch and expose `Environment__c`, `AI_Confidence__c`, and `AI_Reasoning_Status__c`.
- Kept architecture lightweight by applying filters strictly on the client side against the fetched payload.

### Milestone 43D — Near-Realtime Telemetry Widgets: Complete
- Added `avgAiConfidence` and `errorLogCount` metrics to `DashboardSummary`.
- Integrated Average AI Confidence and Error Log Count into the KPI grid in `zentomDashboard.html`.
- Displayed `lastRefreshedLabel` near-realtime timestamp dynamically updated on every payload fetch.
### Milestone 43E — Replay Export / Share: Complete
- Added `getReplayExportData` method in `ZentomDashboardController.cls` returning safe export wrapper.
- Implemented `handleExportCsv` and `handleCopySummary` in `zentomDashboard.js`.
- Attached actions to the Flight Recorder timeline in `zentomDashboard.html`.

### Milestone 43F — Approval Escalation Paths: Planning
- Drafted initial plan in `docs/approval-escalation-paths-plan.md`.
- Focus on visually identifying overdue incidents in the Approval Queue.
