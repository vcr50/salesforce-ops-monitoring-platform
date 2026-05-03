# SentinelFlow Experience Cloud Plan

This document describes how to evolve SentinelFlow from an internal Salesforce Lightning app into a more polished Experience Cloud portal with cleaner navigation, simpler task flows, and a more intentional UI/UX layer.

## Goal

Use Experience Cloud as the presentation layer for SentinelFlow while keeping the current Salesforce data model, Apex automation, reports, and internal admin app intact.

## Recommended Model

- Keep `SentinelFlow Console` as the internal operations/admin workspace.
- Build an Experience Cloud site as the external or semi-external portal experience.
- Reuse the existing SentinelFlow objects:
  - `Incident__c`
  - `Integration_Log__c`
  - `SLA_Policy__c`
  - `Environment__c`
  - `Deployment_Record__c`
  - `Audit_Trail__c`
- Reuse current Apex automation and reports where possible.

## User Experience Direction

The Experience Cloud site should not feel like raw Salesforce setup pages. It should feel like a focused monitoring portal.

Recommended UX direction:

- clear landing page with operational summary
- simplified navigation
- task-oriented pages instead of object-oriented pages where possible
- high-signal status cards for incidents and failed integrations
- fewer columns and less table overload on first load
- use branding, spacing, and page sections to reduce the “admin console” feel

## Target Users

### Internal Operations Admins

Use case:

- manage incidents
- review failed integrations
- inspect audit history
- tune policies
- operate from the internal Lightning app

Recommended surface:

- `SentinelFlow Console`

### Business Stakeholders or Support Leads

Use case:

- view live operational status
- review open and critical incidents
- see major integration failures
- consume dashboards and summary data

Recommended surface:

- Experience Cloud portal

### External or Limited-Access Users

Use case:

- see a curated subset of incidents or status pages
- follow escalation progress

Recommended surface:

- Experience Cloud portal with narrower sharing and permissions

## Experience Cloud Site Map

### 1. Home

Purpose:

- operational summary page
- show current health at a glance

Recommended content:

- critical incidents card
- open incidents card
- failed integrations card
- warning integrations card
- “recent escalations” table
- “last refreshed” status

### 2. Incidents

Purpose:

- primary work queue for incident monitoring

Recommended content:

- open incidents list
- severity filters
- status filters
- quick actions for drill-in

Recommended source:

- custom LWC over `Incident__c`
- or Experience Builder page backed by reports/list views for an early version

### 3. Integrations

Purpose:

- monitor failed and degraded integrations

Recommended content:

- failed logs
- warning logs
- response time highlights
- API/system name grouping

Recommended source:

- custom LWC over `Integration_Log__c`

### 4. Analytics

Purpose:

- reporting and trend review

Recommended content:

- embedded SentinelFlow reports
- dashboard components
- links to detailed reports

Recommended source:

- current reports:
  - `Open Incidents`
  - `Critical Open Incidents`
  - `Failed Integration Logs`

### 5. Incident Detail

Purpose:

- focused review page for a single incident

Recommended content:

- severity
- status
- linked integration log
- environment
- SLA policy
- timeline or audit context

Recommended source:

- record page or custom detail LWC

### 6. Escalation / Support

Purpose:

- give users a clear path when something needs attention

Recommended content:

- contact guidance
- escalation steps
- optional form or quick action

## Build Strategy

### Phase 1: Portal Foundation

- enable an Experience Cloud site
- choose a template with simple navigation
- set branding, theme, and navigation
- create page shells:
  - Home
  - Incidents
  - Integrations
  - Analytics

### Phase 2: Data Experience

- surface current reports in the portal
- add filtered list experiences
- simplify columns for readability
- validate access rules for portal users

### Phase 3: Custom LWC Layer

Build portal-focused LWCs for:

- health summary cards
- incidents data table
- failed integrations table
- status KPIs
- incident detail view

This is the stage where UX improves the most over standard Salesforce pages.

### Phase 4: Advanced Experience

- branded dashboard experience
- guided actions
- better drill-down flows
- optional Node.js middleware-backed APIs for richer visualizations

## Permission and Sharing Approach

Use a separate permission model for the portal.

Recommended structure:

- keep `SentinelFlow_Admin` and `SentinelFlow_Runtime_Admin` for internal users
- create portal-specific permission sets, such as:
  - `SentinelFlow_Portal_Viewer`
  - `SentinelFlow_Portal_Support`

Portal users should usually have:

- read access to `Incident__c`
- read access to `Integration_Log__c`
- restricted or no access to setup-oriented objects unless needed
- limited access to `Audit_Trail__c` depending on audience

## Recommended Components

### Reuse Standard Components First

- report chart
- report table
- record detail
- list view
- rich text

### Build Custom Components Where UX Matters Most

- incident summary cards
- active issue banner
- integration health matrix
- SLA breach indicator
- refreshed timestamp/status banner

## What Stays Internal vs Portal

### Keep Internal

- object administration
- policy maintenance
- permission management
- deep audit review
- metadata/admin operations

### Move to Experience Cloud

- operational summaries
- incident monitoring
- failed integration views
- curated analytics
- guided incident drill-down

## Technical Notes for This Repo

Current repo strengths that support this move:

- SentinelFlow objects are already modeled in `force-app/main/default/objects/`
- Apex automation already manages incident lifecycle from integration logs
- reports already exist for incident and failed-log monitoring
- sample data seed exists for demo workflows:
  - `scripts/salesforce/seed-dashboard-sample-data.apex`

Likely repo additions for Experience Cloud:

- ExperienceBundle metadata
- Network metadata
- portal-specific LWCs under `force-app/main/default/lwc/`
- new permission sets for portal users
- portal navigation and theme metadata

## Suggested First Implementation Slice

Build the smallest valuable Experience Cloud version first:

1. Home page
2. Incidents page
3. Integrations page
4. Analytics page

Use:

- current reports for analytics
- current sample data for demo
- current Apex automation for live behavior

This gives you a presentable portal quickly without forcing a full redesign on day one.

## Next Recommended Step

Create an Experience Cloud build checklist and metadata scaffold for:

- site creation
- permission sets
- page inventory
- initial LWCs

That would be the best next implementation document before writing metadata.
