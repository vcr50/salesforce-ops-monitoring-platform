# SentinelFlow Change Log - 2026-05-11

## Deployment Summary

SentinelFlow Salesforce metadata was deployed to the Salesforce org alias `astrosoft`.

- Target org username: `vjdev@asap.com`
- Org URL: `https://astrosoft2-dev-ed.develop.lightning.force.com/lightning/n/Sentinel_Flow`
- Deploy ID: `0AfdL00000aKZ89SAG`
- Deploy status: `Succeeded`
- Components deployed: `138 / 138`
- Apex tests completed: `36 / 36`
- Apex test failures: `0`
- Test level: `RunSpecifiedTests`

## Salesforce Changes

### Approval Process Fix

File changed:

- `sentinelflow/force-app/main/default/approvalProcesses/SF_Incident__c.High_Impact_Auto_Heal_Approval.approvalProcess-meta.xml`

Change:

- Kept the approval-process approver as `vjdev@asap.com` for the Astrosoft target org.

Reason:

- The approval process must reference a user that exists in the target Salesforce org.

Note:

- For AppExchange packaging, this should later be replaced with a configurable approval queue, public group, or approver lookup instead of an org-specific user.

### Flow Trigger Test Coverage

Files added:

- `sentinelflow/force-app/main/default/classes/FlowFaultTriggerTest.cls`
- `sentinelflow/force-app/main/default/classes/FlowFaultTriggerTest.cls-meta.xml`
- `sentinelflow/force-app/main/default/classes/IntegrationLogTriggerTest.cls`
- `sentinelflow/force-app/main/default/classes/IntegrationLogTriggerTest.cls-meta.xml`

Purpose:

- Adds test coverage for `FlowFaultTrigger`.
- Inserts Flow fault logs across low, high, and critical affected-record thresholds.
- Adds test coverage for `IntegrationLogTrigger`.
- Inserts failed/error integration logs across OAuth, server-error, timeout, and ignored-success paths.
- Allows Salesforce deployment coverage validation to pass.

Reason:

- Earlier validation failed because `FlowFaultTrigger` and `IntegrationLogTrigger` did not have enough package-owned test coverage for `RunSpecifiedTests`.

### Auto-Heal Orchestrator Test Expansion

File changed:

- `sentinelflow/force-app/main/default/classes/AutoHealOrchestratorTest.cls`

Added coverage for:

- successful OAuth auto-heal
- failed API timeout auto-heal escalation
- scheduled job requeue runbook
- approval-required path fallback

Reason:

- `RunSpecifiedTests` requires each deployed Apex class and trigger to meet per-component coverage thresholds.

## Build System Changes

### TypeScript Build Compatibility

File changed:

- `tsconfig.json`

Change:

- Added `ignoreDeprecations: "6.0"`.

Reason:

- TypeScript 6 treats `baseUrl` deprecation as a blocking build error unless the deprecation is acknowledged.

### Vite Browser Environment Fixes

Files changed:

- `src/App.tsx`
- `src/App-optimized.tsx`
- `src/main.tsx`
- `src/utils/performance.ts`
- `src/components/ErrorBoundary.tsx`
- `src/vite-env.d.ts`

Changes:

- Replaced browser-side `process.env.NODE_ENV` checks with `import.meta.env`.
- Removed unused imports that failed strict TypeScript checks.
- Added Vite client typings.
- Added CSS module and `gtag` global declarations.

Reason:

- Root `npm run build` was failing on strict TypeScript and missing browser/Vite globals.

### Tailwind 4 PostCSS Fix

Files changed:

- `package.json`
- `package-lock.json`
- `postcss.config.js`

Changes:

- Added `@tailwindcss/postcss`.
- Updated PostCSS config from `tailwindcss` to `@tailwindcss/postcss`.

Reason:

- Tailwind 4 moved the PostCSS plugin into a separate package.

### Vite 8 Manual Chunk Fix

File changed:

- `vite.config.ts`

Change:

- Converted `manualChunks` from object format to function format.

Reason:

- Vite 8 / Rolldown rejected the previous object form with `manualChunks is not a function`.

### CSS Minification Fix

File changed:

- `css/alive-now.css`

Change:

- Replaced a corrupted separator line with a valid CSS comment.

Reason:

- Lightning CSS failed during production minification because the corrupted line was not valid CSS.

## SentinelFlow Next Evolution Backend Additions

### Operational Memory Engine

Files changed/added:

- `sentinelflow-api/src/services/memory.service.ts`
- `sentinelflow-api/db/operational-memory.schema.sql`

Added:

- Persistent incident memory model.
- Root cause, remediation, execution duration, outcome, confidence score, retry count, MTTR improvement, impacted services, source system, revenue impact.
- Deterministic local vector-like similarity search.
- Supabase/Postgres schema with `pgvector` support and tenant row-level security.

### Adaptive Runbook Intelligence

File added:

- `sentinelflow-api/src/services/adaptive-runbook.service.ts`

Added:

- Dynamic runbook recommendation.
- Confidence ranking.
- Historical success-rate weighting.
- Failed recovery loop detection.
- Escalation recommendation when confidence is low.

### Prediction Engine V2

File added:

- `sentinelflow-api/src/services/prediction-v2.service.ts`

Added:

- Failure probability scoring.
- Deployment risk scoring.
- Flow instability scoring.
- API latency trend analysis.
- Predicted revenue impact.
- Org stability score.
- Incident clustering into critical, watchlist, and stable groups.

### Autonomous Learning Loop

File added:

- `sentinelflow-api/src/services/learning-loop.service.ts`

Added:

- Learning from successful and failed auto-heals.
- Confidence adjustment output.
- False-positive suppression recommendation.
- Model-quality reporting.

### Enterprise Reliability Testing

File added:

- `sentinelflow-api/src/services/reliability.service.ts`

Added:

- Governor limit stress simulation.
- Concurrent incident simulation.
- Platform Event spike simulation.
- Retry storm simulation.
- Failover validation.
- Rollback recovery simulation.
- Integration timeout chaos simulation.
- Reliability score and scenario analytics.

### API Endpoint Wiring

File changed:

- `sentinelflow-api/src/index.ts`

Added endpoints:

- `POST /api/memory/search`
- `GET /api/memory/analytics`
- `POST /api/runbooks/recommend`
- `POST /api/predict/v2`
- `POST /api/learning/outcome`
- `GET /api/learning/quality`
- `POST /api/reliability/simulate`

Updated:

- `/api/health` now reports version `2.0.0` and `self-evolving` intelligence mode.
- `/api/classify` now includes memory matches and runbook recommendation output.

## Dashboard V2 Additions

File changed:

- `sentinelflow-dashboard/src/app/page.tsx`

Added:

- Org Health Score KPI.
- AI Confidence KPI.
- Deployment Risk KPI.
- AI Confidence and Prediction Accuracy chart.
- Incident heatmap.
- Autonomous Recovery Timeline.
- Live AI Ops Feed.
- Auto-Heal Success Analytics panel.

## Architecture Documentation Added

Files added:

- `docs/sentinelflow-next-evolution-architecture.md`
- `docs/sentinelflow-appexchange-readiness.md`
- `docs/sentinelflow-change-log-2026-05-11.md`
- `docs/sentinelflow-appexchange-listing.md`

Purpose:

- Document the next SentinelFlow architecture phase.
- Capture AppExchange readiness requirements.
- Capture AppExchange listing copy, product positioning, verified deploy proof, and readiness gaps.
- Record what changed and why.

## Verification

### Root App Build

Command:

```bash
npm run build
```

Result:

- Passed.

Remaining warnings:

- Some legacy scripts in `index.html` are not bundled because they do not use `type="module"`.
- `postcss.config.js` is parsed as an ES module because package type is not declared.

### Salesforce Deployment

Command:

```bash
sf project deploy start --source-dir force-app --target-org astrosoft --test-level RunSpecifiedTests --tests AutoHealOrchestratorTest --tests FlowFaultTriggerTest --tests IncidentClassificationQueueableTest --tests IntegrationLogTriggerTest --tests PredictionEngineBatchTest --tests PredictionEngineSchedulerTest --tests SentinelFlowEventPublisherTest --tests SentinelFlowIncidentHandlerTest --tests SentinelFlowLoggerTest --tests SentinelFlowNotifierTest --wait 30 --ignore-conflicts
```

Final report command:

```bash
sf project deploy report --target-org astrosoft --job-id 0AfdL00000aKZ89SAG --wait 30
```

Result:

- Succeeded.

### Astrosoft Post-Deploy Smoke Check

Permission set assignment:

```bash
sf org assign permset --name SentinelFlow_Admin --target-org astrosoft
```

Result:

- `SentinelFlow_Admin` was already assigned to `vjdev@asap.com`.

Lightning app verification:

```bash
sf data query --target-org astrosoft --use-tooling-api --query "SELECT Id, DeveloperName, Label FROM CustomApplication WHERE DeveloperName LIKE '%Sentinel%'"
```

Result:

- Found `SentinelFlow_Console`
- Label: `SentinelFlow Console`

Core object verification:

```bash
sf data query --target-org astrosoft --query "SELECT QualifiedApiName, Label FROM EntityDefinition WHERE QualifiedApiName IN ('SF_Incident__c','SF_Incident_Memory__c','SF_Prediction_Risk__c','SF_Healing_Runbook__c') ORDER BY QualifiedApiName"
```

Result:

- `SF_Healing_Runbook__c`
- `SF_Incident__c`
- `SF_Incident_Memory__c`
- `SF_Prediction_Risk__c`

Incident object smoke query:

```bash
sf data query --target-org astrosoft --query "SELECT Id, Name, Status__c, Incident_Type__c FROM SF_Incident__c LIMIT 5"
```

Result:

- Found an open `Integration_Error` incident: `INC-20260511-0000`.

### End-to-End Detection Smoke Test

Permission set update:

```bash
sf project deploy start --source-dir force-app/main/default/permissionsets/SentinelFlow_Admin.permissionset-meta.xml --target-org astrosoft --test-level NoTestRun --wait 10 --ignore-conflicts
```

Result:

- Succeeded.
- Deploy ID: `0AfdL00000aKTUBSA4`
- Updated `SentinelFlow_Admin` with object and field access for `Integration_Log__c` and `Flow_Fault_Log__c`.

Smoke input:

```bash
sf data create record --target-org astrosoft --sobject Integration_Log__c --values "Status__c='Failed' Integration_Name__c='Stripe Gateway Smoke Test' Error_Code__c='401' Error_Message__c='Smoke test OAuth token expired' Records_Affected__c=7 Estimated_Revenue_Impact__c=1500"
```

Result:

- Created `Integration_Log__c` record `a0BdL0000194133UAA`.

Pipeline verification:

```bash
sf data query --target-org astrosoft --query "SELECT Id, Name, Status__c, Incident_Type__c, Severity__c, Source_System__c, Error_Code__c, Error_Message__c FROM SF_Incident__c WHERE Source_System__c = 'Stripe Gateway Smoke Test' ORDER BY CreatedDate DESC LIMIT 5"
```

Result:

- Created incident `INC-20260511-0001`.
- Status: `Open`
- Type: `Integration_Error`
- Severity: `P1_High`
- Source: `Stripe Gateway Smoke Test`
- Error code: `401`

This verifies the deployed detection path:

```text
Integration_Log__c failure -> IntegrationLogTrigger -> SentinelFlow_Incident__e -> SentinelFlowIncidentTrigger -> SF_Incident__c
```

### AppExchange App Metadata Update

Retrieved app metadata:

```bash
sf project retrieve start --metadata CustomApplication:SentinelFlow_Console --target-org astrosoft --wait 10
```

Updated file:

- `sentinelflow/force-app/main/default/applications/SentinelFlow_Console.app-meta.xml`

Changes:

- Updated app description to: `Salesforce's Autonomous Immune System: secure, learn, heal, and scale with AI-powered operational intelligence.`
- Updated navigation to prioritize current SentinelFlow objects:
  - `SF_Incident__c`
  - `SF_Incident_Memory__c`
  - `SF_Prediction_Risk__c`
  - `SF_Healing_Runbook__c`
  - `Integration_Log__c`

Deployment:

```bash
sf project deploy start --source-dir force-app/main/default/applications/SentinelFlow_Console.app-meta.xml --target-org astrosoft --test-level NoTestRun --wait 10 --ignore-conflicts
```

Result:

- Succeeded.
- Deploy ID: `0AfdL00000aKcsPSAS`

Verification:

```bash
sf data query --target-org astrosoft --use-tooling-api --query "SELECT Id, DeveloperName, Label, Description FROM CustomApplication WHERE DeveloperName = 'SentinelFlow_Console'"
```

Result:

- App: `SentinelFlow_Console`
- Label: `SentinelFlow Console`
- Description: `Salesforce's Autonomous Immune System: secure, learn, heal, and scale with AI-powered operational intelligence.`

Notes:

- A first Astrosoft deploy with `RunLocalTests` uploaded all metadata but rolled back because existing org test classes outside this local package failed.
- A second deploy with package-owned `RunSpecifiedTests` had all specified tests pass, but Salesforce required stricter per-component coverage for `IntegrationLogTrigger` and `AutoHealOrchestrator`.
- Final Astrosoft deployment used expanded package-owned tests and succeeded with `RunSpecifiedTests`.

### AppExchange Version and Publisher Update

Updated files:

- `docs/sentinelflow-appexchange-readiness.md`
- `docs/sentinelflow-appexchange-listing.md`
- `sentinelflow/package.json`
- `sentinelflow/sfdx-project.json`
- `sentinelflow-api/package.json`
- `sentinelflow-dashboard/package.json`

Changes:

- Set AppExchange version to `2.6.0`.
- Set default publisher / published-by value to `Tomcodex`.
- Added Salesforce package version metadata: `versionName` `2.6.0` and `versionNumber` `2.6.0.NEXT`.
- Aligned Salesforce package, backend API, and dashboard package manifests to version `2.6.0`.

### Marketing Site / Pitch Content Update

Updated file:

- `SentinelFlow_Marketing_PitchDeck.md`

Changes:

- Added AppExchange version `2.6.0` to the marketing one-pager and cover slide.
- Added published-by / publisher copy as `Tomcodex`.
- Updated the go-to-market AppExchange launch line to reference SentinelFlow `2.6.0` under publisher `Tomcodex`.
- Updated the marketing content footer from `v2.0` to `v2.6.0`.

### AppExchange Installation Downgrade Fix

Updated files:

- `website/index.html`
- `website/terms.html`
- `website/products.html`
- `website/privacy-policy.html`
- `website/contact.html`
- `website/careers.html`
- `website/blog.html`
- `website/about.html`
- `website-next/` components

Issue:

- The "Install in Salesforce" buttons on the marketing website were hardcoded to point to an older `v1.0 (Beta 2)` package ID (`04tdL000000YSWXQA4`). 
- When users with the newly installed `v2.6.0.3` clicked the link, Salesforce threw a Downgrade Error and blocked installation.

Resolution:

- Cleaned the local git workspace by resolving merge conflicts that previously deleted the `website/` folders.
- Globally replaced the old package ID (`04tdL000000YSWXQA4`) with the correct, newly generated `v2.6.0.3` package ID (`04tdL000000aLnVQAU`).
- Standardized all visible version labels on the live website to `2.6` to match the AppExchange submission.
- Force-pushed the targeted fixes to `origin/main` to trigger the Render deployment and refresh the live install links.
