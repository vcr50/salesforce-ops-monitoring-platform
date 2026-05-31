# Dashboard Menu + Card Polish

## Purpose
Polish the current SentinelFlow Command Center skeleton so it looks cleaner, more readable, and beta-demo ready.

## Product Architecture Reminder
SentinelFlow = Salesforce app / skeleton / command center.
Zentom = neural brain / intelligence layer.

## Scope
UI/UX polish only:
- Menus
- Cards
- Spacing
- Text contrast
- Card consistency
- Placeholder pages
- Future data mapping

## Not in Scope
- No Apex changes
- No backend changes
- No new objects
- No new features
- No real neural data connection yet

## Screenshots Reviewed
- Dashboard home
- Pending approval queue
- Actions placeholder
- Sidebar menu
- System health / cards

## Current Issues
1. Header height needs polish.
2. Table text contrast should improve.
3. Card spacing should be consistent.
4. Sidebar menu needs tighter alignment.
5. Placeholder pages should look intentional.
6. Cards need common style classes.
7. Future data mapping should be documented.

## UI Polish Tasks
- Standardize card style.
- Improve sidebar active state.
- Reduce header empty space.
- Improve KPI card spacing.
- Improve table readability.
- Improve action placeholder cards.
- Improve system health section.

## Future Data Mapping
- Org Health Score → ZentomDashboardController
- Pending Approvals → Sentinel_Incident__c
- Recent Incidents → Sentinel_Incident__c
- Replay Timeline → Sentinel_Audit_Log__c
- Error Logs → Sentinel_Error_Log__c
- Actions → approved execution records / Cases
- Neural Insights → future Zentom Brain layer

## Success Criteria
- Dashboard looks cleaner.
- Text is readable.
- Menus feel app-like.
- Cards are consistent.
- Existing behavior is preserved.
- Future data connection is mapped.
