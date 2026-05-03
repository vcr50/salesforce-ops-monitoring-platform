# SentinelFlow Data Model Baseline

This baseline captures the custom Salesforce objects planned for SentinelFlow.

## Core Objects

### `Incident__c`

- Purpose: Track operational incidents raised from failed integrations, deployment issues, or platform health breaches.
- Key fields: `Severity__c`, `Status__c`, `Description__c`, `SLA_Policy__c`, `Integration_Log__c`, `Environment__c`, `Resolved_Time__c`

### `Integration_Log__c`

- Purpose: Capture integration execution events and API outcomes.
- Key fields: `API_Name__c`, `Status__c`, `Response_Time__c`, `Error_Message__c`

### `SLA_Policy__c`

- Purpose: Define severity-based response and resolution targets.
- Key fields: `Severity__c`, `Response_Time_Min__c`, `Resolution_Time_Min__c`

### `Environment__c`

- Purpose: Represent a monitored org or deployment environment.
- Key fields: `Name`, `Org_Id__c`

### `Deployment_Record__c`

- Purpose: Track deployment start, end, and result state.
- Key fields: `Version__c`, `Status__c`, `Start_Time__c`, `End_Time__c`

### `Audit_Trail__c`

- Purpose: Preserve auditable changes taken by users or automation.
- Key fields: `User__c`, `Action__c`, `Object_Name__c`, `Old_Value__c`, `New_Value__c`, `Timestamp__c`

## Phase 1 Output

Phase 1 documents the object model and exposes it through application configuration. Actual Salesforce metadata creation remains a deployment activity for the org owner or a future Salesforce DX package.
