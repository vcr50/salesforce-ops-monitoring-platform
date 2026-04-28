# SEOMP Experience Cloud Build Checklist

This checklist converts the Experience Cloud plan into concrete implementation steps for this repo and org.

## 1. Org Readiness

- Enable Experience Cloud in the target org.
- Confirm a site template is available.
- Confirm portal users or test users are available.
- Confirm the `SEOMP_Dashboards` folder and `SEOMP_Analytics` reports are visible to the intended audience.

## 2. Metadata Already Reusable

The following pieces are already available and should be reused:

- SEOMP custom objects
- incident automation and triggers
- report folder `SEOMP_Analytics`
- dashboard folder `SEOMP_Dashboards`
- sample data seed:
  - `scripts/salesforce/seed-dashboard-sample-data.apex`

## 3. Repo Scaffolding Added

This repo now includes:

- portal permission sets:
  - `SEOMP_Portal_Viewer`
  - `SEOMP_Portal_Support`
- starter LWCs:
  - `seompPortalSummary`
  - `seompPortalIncidentTable`
  - `seompPortalIntegrationTable`

## 4. Site Structure To Build

Create these pages in Experience Builder:

- Home
- Incidents
- Integrations
- Incident Detail
- Integration Detail
- Analytics
- Escalation

## 5. Component Placement

### Home

- `tomcodexServicePage`
- `seompPortalSummary`
- rich text intro / status guidance
- optional report chart or report table

### Incidents

- `seompPortalIncidentTable`
- filters or standard list/report components

### Integrations

- `seompPortalIntegrationTable`
- failed log and warning log views

### Incident Detail

- `seompPortalIncidentDetail`
- route/page path:
  - `incident-detail`

### Integration Detail

- `seompPortalIntegrationDetail`
- route/page path:
  - `integration-detail`

### Analytics

- standard report chart/table components
- links to:
  - `Open Incidents`
  - `Critical Open Incidents`
  - `Failed Integration Logs`

### Escalation

- rich text instructions
- contact and ownership guidance

## 6. Permission Model

### Portal Viewer

Use for read-only stakeholders.

Should have:

- read access to incidents
- read access to integration logs
- read access to environments
- read access to deployment records
- limited or no access to audit trail

### Portal Support

Use for internal support-style users in the portal.

Should have:

- edit access to incidents
- read access to integration logs
- read access to environments and SLA policies

## 7. Data Validation

Before demoing the portal:

- run sample data seed if needed
- confirm open incidents exist
- confirm critical incidents exist
- confirm failed logs exist
- confirm reports load for portal users

## 8. UX Cleanup Pass

Before calling the portal ready:

- rename pages clearly
- remove unused navigation items
- simplify columns shown in report/list components
- apply theme and branding
- keep page density lower than standard Lightning setup pages

## 9. Next Technical Slice

After the starter portal works:

- replace standard report/list blocks with richer custom LWCs
- add Apex-backed aggregate summary endpoints if needed
- add incident drill-down and escalation actions
  - this repo now includes starter incident and integration detail components

## 10. Deployment Reminder

When new Experience Cloud metadata is added later, update:

- `manifest/package.xml`
- permission set assignments
- any site-specific navigation or branding metadata
