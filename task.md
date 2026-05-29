# Milestone 49: Streaming Telemetry Implementation

## 49A — Create SentinelFlow_Dashboard_Event__e metadata ✅
- [x] Create object-meta.xml for `SentinelFlow_Dashboard_Event__e`
- [x] Create 13 field metadata files in `fields/` subdirectory
- [x] Enforce `HighVolume` event type and `PublishAfterCommit` behavior
- [x] Ensure fields omit secrets, raw payloads, and hidden AI reasoning
- [x] Update `docs/maintenance.md`
- [x] Update `task.md`

## 49B — Create SentinelFlowEventPublisher Apex service
- [ ] Create `SentinelFlowEventPublisher.cls` with publish, publishBulk, and publishSystemEvent methods
- [ ] Implement `publishedIncidentIds` recursion guard set
- [ ] Create `SentinelFlowEventPublisherTest.cls` matching unit test specifications
- [ ] Achieve 100% code coverage on publisher service class

## 49C — Emit events from incident approval/action/error flows
- [ ] Modify `SentinelIncidentTrigger.trigger` to publish `INCIDENT_CREATED`, `APPROVAL_REQUIRED`, and `RISK_UPDATED` events
- [ ] Modify `ZentomDashboardController.cls` to publish `APPROVED`, `REJECTED`, `ACTION_READY`, `ACTION_EXECUTED`, and `CASE_CREATED` events
- [ ] Modify `SentinelFlowNotificationDispatcher.cls` to publish `ERROR_LOGGED` event on webhook fail
- [ ] Verify webhook/trigger backward compatibility in tests

## 49D — Add LWC empApi subscription to dashboard
- [ ] Create `force-app/main/default/lwc/streamingTelemetry` utility module
- [ ] Implement subscription, unsubscription, and global error listener APIs
- [ ] Import utility module in `zentomDashboard.js`
- [ ] Implement 2-second debounce mechanism for data refreshing
- [ ] Subscribe to dashboard and integration health events

## 49E — Add fallback polling/reconnect behavior
- [ ] Implement dynamic polling interval switching (60s active / 30s fallback)
- [ ] Implement CometD transport error listeners and connection drop triggers
- [ ] Implement silent background 30-second re-subscription retry loop
- [ ] Guarantee cleanup of timers and subscriptions in `disconnectedCallback()`

## 49F — Validate streaming + regression tests
- [ ] Deploy streaming telemetry implementation to `astrosoft` sandbox
- [ ] Validate manual QA scenarios A (incident insert toast), B (approval queue refresh), C (adaptive polling drops), and D (portal regressions)
- [ ] Execute full Apex test suite (400+ unit tests) and ensure 100% success

## 49G — Streaming telemetry implementation wrap-up
- [ ] Update `docs/maintenance.md` with final results
- [ ] Create implementation walkthrough / design results documentation
- [ ] Commit all implementation files and push to remote
