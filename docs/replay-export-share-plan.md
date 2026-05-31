# Milestone 43E: Replay Export / Share Plan

## 1. Purpose
To allow SentinelFlow users to easily extract and share the Replay Timeline of an incident for auditing, root cause analysis (RCA), security reviews, and reporting to stakeholders or customers.

## 2. Customer Need
Customers frequently need to provide post-incident reports. Manually screenshotting or copying disparate logs is slow and prone to human error. A simple "Export CSV" or "Copy Summary" function saves time and ensures the exported data is accurate and correctly formatted.

## 3. Export Scope
- **Format:** CSV file download.
- **Trigger:** A "Download CSV" button on the incident details modal or replay timeline view.
- **Data:** Chronological list of events associated with the incident's timeline.

## 4. Share Scope
- **Format:** Formatted text copied directly to the user's clipboard.
- **Trigger:** A "Copy Summary" button on the incident details modal.
- **Data:** A concise, human-readable summary of the incident state and timeline.
- **Note:** Native "Open in Salesforce" link will also be provided to route users to the actual record page.

## 5. Fields Included
- `Event Name` (Type of event: Detection, Policy Decision, Execution)
- `Timestamp` (When it happened)
- `Status / Decision` (e.g., Approved, Executed, Failed)
- `Actor / Approved By` (System AI or Human user)
- `Runbook Key` / `Incident Type`
- `Safe Replay Explanation` (Sanitized description of the event)

## 6. Fields Excluded
- Raw HTTP Request/Response payloads
- Internal system IDs (unless strictly necessary for URL mapping)
- Unfiltered stack traces or raw integration errors that might contain secrets
- Hidden AI reasoning vectors/prompts

## 7. Security / Privacy Rules
- **No secrets or API keys** will be included in the export.
- **No raw sensitive payloads** from the `Sentinel_Audit_Log__c` records will be exposed.
- Only the sanitized, safe explanation generated for the audit log / timeline is permitted to be exported.

## 8. CSV Export Behavior
When the user clicks "Export CSV":
1. A client-side JavaScript function will gather the current incident's replay timeline data.
2. The data will be formatted into a standard CSV string.
3. A temporary `<a>` element will be created with a `data:text/csv` URI to trigger a native browser download.
4. The filename will follow the convention: `Sentinel_Incident_{IncidentName}_Timeline.csv`.

## 9. Copy Summary Behavior
When the user clicks "Copy Summary":
1. A client-side JavaScript function will compile a short summary string (e.g., "Incident [Name] - [Type] - Status: [Status]...").
2. The `navigator.clipboard.writeText()` API will be used to copy the string to the user's clipboard.
3. A brief "Copied!" toast or indicator will confirm success.

## 10. Validation Checklist
- [ ] Verify CSV downloads correctly with all expected safe fields.
- [ ] Verify CSV does NOT contain any raw payloads or secrets.
- [ ] Verify Copy Summary successfully writes formatted text to the clipboard.
- [ ] Verify the "Open Record" link correctly routes to the `Sentinel_Incident__c` detail page.
- [ ] Run Apex tests for any new backend data retrieval methods.
