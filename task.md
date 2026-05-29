# Milestone 48: Streaming Telemetry

## 48A — Streaming Telemetry Architecture Plan ✅
- [x] Research current polling model in `zentomDashboard.js` and `ZentomDashboardController.cls`
- [x] Identify existing Platform Events (`Flow_Health_Event__e`, `Integration_Health_Event__e`)
- [x] Identify existing empApi subscriptions (4 Portal LWC components)
- [x] Design hybrid streaming + fallback polling architecture
- [x] Define `SentinelFlow_Dashboard_Event__e` Platform Event contract
- [x] Define event publishing points (triggers, controllers, dispatcher)
- [x] Document governor limit analysis and security considerations
- [x] Define success criteria (functional, performance, safety)
- [x] Create `docs/streaming-telemetry-architecture-plan.md`
- [x] Update `docs/maintenance.md`

## 48B — Platform Event Contract Design ✅
- [x] Define `SentinelFlow_Dashboard_Event__e` with 13 fields
- [x] Define 11 event types with categories and descriptions
- [x] Map 5 emit sources to specific event types with Apex examples
- [x] Design `SentinelFlowEventPublisher` centralized publishing utility
- [x] Define deduplication strategy (trigger-level + LWC debounce)
- [x] Document CometD channel and replay ID strategy
- [x] Create payload examples (INCIDENT_CREATED, APPROVED, DASHBOARD_REFRESH_REQUESTED)
- [x] Security checklist: no raw payloads, no secrets, no PII, no hidden AI reasoning
- [x] Create `docs/streaming-telemetry-platform-event-contract.md`
- [x] Update `docs/maintenance.md`

## 48C — LWC empApi Subscription Design ✅
- [x] Create `streamingTelemetry.js` reusable utility module
- [x] Integrate `empApi` subscription into `zentomDashboard.js`
- [x] Add debounce logic (2-second window)
- [x] Subscribe to `SentinelFlow_Dashboard_Event__e` + existing `Integration_Health_Event__e`
- [x] Add event type filtering for selective refresh (future Phase 2)
- [x] Create `docs/streaming-telemetry-lwc-subscription-design.md`


## 48D — Fallback Polling Strategy ✅
- [x] Implement adaptive polling interval (60s streaming / 30s fallback)
- [x] Add streaming health detection (`isStreamingActive`)
- [x] Ensure `disconnectedCallback` cleans up subscriptions and timers
- [x] Test graceful degradation when streaming is unavailable
- [x] Create `docs/streaming-telemetry-fallback-polling-design.md`


## 48E — Security / Governor Limit Review
- [ ] Update `SentinelFlow_Admin` permission set with `SentinelFlow_Dashboard_Event__e` CRUD
- [ ] Verify FLS compliance for event fields
- [ ] Add `EventBus.publish()` calls to triggers and controllers
- [ ] Validate DML governor limits not exceeded with event publishing

## 48F — Prototype Validation
- [ ] Deploy all changes to `astrosoft`
- [ ] Test: Incident insert → dashboard updates within 3 seconds
- [ ] Test: Approval approve/reject → dashboard updates instantly
- [ ] Test: Streaming disconnected → polling resumes at 30s
- [ ] Test: No duplicate refreshes from stream + poll overlap
- [ ] Test: Portal LWC streaming components unaffected (regression)
- [ ] Run full Apex test suite (400+ tests)

## 48G — Streaming Telemetry Wrap-up
- [ ] Update `docs/maintenance.md` with final status
- [ ] Create walkthrough documentation
- [ ] Commit and push all changes
- [ ] Tag if applicable
