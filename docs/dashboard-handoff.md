# Dashboard Handoff

The SEOMP reports are deployed in `astrosoft2-dev-ed`, but a deployable `Dashboard` metadata file is not yet in source control.

## Current state

- `ReportFolder` deployed: `SEOMP_Analytics`
- Reports deployed:
  - `SEOMP_Analytics/Open_Incidents`
  - `SEOMP_Analytics/Critical_Open_Incidents`
  - `SEOMP_Analytics/Failed_Integration_Logs`
- `DashboardFolder` deployed: `SEOMP_Dashboards`

## Why the dashboard file is not in source

The org allows dashboard querying through the data and Analytics REST APIs, but metadata retrieve for `Dashboard` currently returns a permissions warning:

`You do not have the proper permissions to access Dashboard.`

Because of that, the exact metadata XML shape could not be retrieved from the org, and no undeployable dashboard file was kept in the repo.

## Recommended next step

1. Create a dashboard manually in Salesforce UI under the `SEOMP_Dashboards` folder.
2. Add components that use:
   - `Open Incidents`
   - `Critical Open Incidents`
   - `Failed Integration Logs`
3. After dashboard metadata access is available, retrieve it into source.

## Retrieve command

Replace `<dashboard-developer-name>` with the dashboard API/developer name from the org:

```powershell
sf project retrieve start --metadata "Dashboard:SEOMP_Dashboards/<dashboard-developer-name>" --target-org astrosoft2-dev-ed --ignore-conflicts
```

## Validate after retrieve

```powershell
sf project deploy start --source-dir force-app/main/default/dashboards --target-org astrosoft2-dev-ed --ignore-conflicts
```
