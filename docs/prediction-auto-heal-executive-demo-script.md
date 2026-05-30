# Prediction + Auto-Heal Executive Demo Script

This document provides a clean, detailed speaking script and presenter cues for demonstrating SentinelFlow and Zentom AI to Chief Technology Officers (CTOs), Chief Information Officers (CIOs), Salesforce Architects, and Operations Leaders.

---

## 1. Opening Pitch
**[Presenter Cue: Display Command Center Dashboard Overview]**

**Speaking Script**:  
"Good morning, everyone. SentinelFlow turns Salesforce operations from reactive firefighting into predictive, governed, and auditable AI-assisted operations. Today, we are going to show you how SentinelFlow combines modern AI telemetry, risk-aware governance policies, and automated healing actions to protect your critical Salesforce environments, slash downtime, and document absolute compliance proof for every action."

---

## 2. Problem Statement
**[Presenter Cue: Display Anomaly Signal Grid]**

**Speaking Script**:  
"In most enterprise Salesforce orgs, when an integration fails, a CPU ceiling is hit, or a flow is exhausted, teams only find out *after* business users complain. SREs then spend hours digging through debug logs to find the root cause, and then manually execute scripts or update records to resolve the issue. This firefighting model is slow, expensive, and creates a significant GRC blind spot, as manual terminal changes leave no central compliance trail."

---

## 3. Product Positioning
**[Presenter Cue: Transition to Zentom AI Panel]**

**Speaking Script**:  
"SentinelFlow changes this by establishing a proactive, policy-governed runtime layer. Zentom AI analyzes telemetry signals in near-real-time to generate explainable warnings before outages happen. If action is required, SentinelFlow's execution service maps the action against strict safety policies, checks user permissions, enforces mandatory human clearance for high-risk changes, and rolls back transaction state automatically if an error occurs. We give you automation without sacrificing safety."

---

## 4. Demo Flow
**Speaking Script**:  
"Our demonstration today is structured into five core chapters:
1. **The Prediction Warning**: How Zentom AI translates telemetry signals into explainable predictions.
2. **The Guardian Gate**: How our policy engine blocks unapproved high-risk executions.
3. **Auto-Heal Execution**: Proving autonomous and governed recovery actions work.
4. **GRC Compliance Audit**: Showing write-once audit logs and trace UUID tracking.
5. **Cost & Value Analytics**: Revealing real-time financial ROI metrics directly on the dashboard."

---

## 5. Prediction Card Explanation
**[Presenter Cue: Highlight Critical Prediction Card]**

**Speaking Script**:  
"Here is a Zoho CRM timeout spike. Zentom AI correlates HTTP 504 errors, Apex exceptions, and a recent deployment signal. Rather than sending a cryptic alert, Zentom AI generates a warning card explaining exactly what is wrong in plain language. From this card, SREs have clear operator actions: they can review detailed signal weights, dismiss the warning, or request execution approval. The interface is clean, informative, and designed for speed."

---

## 6. Guardian Gate Explanation
**[Presenter Cue: Display Sentinel Incident Record page with 'Pending Approval']**

**Speaking Script**:  
"Now let's talk about control. SREs cannot execute actions arbitrarily. Because this incident has a critical risk score, it hits our **Guardian Gate**. If an SRE tries to trigger a recovery action now, the system blocks the DML immediately, throws a governance exception, and logs an approval-required block event. High-risk actions require explicit human clearance."

---

## 7. Auto-Heal Execution Explanation
**[Presenter Cue: Display Incident Record transitioning to 'Executed']**

**Speaking Script**:  
"Once an authorized manager approves the clearance request, the status releases. The execution engine runs the recovery action—such as creating a case or task—and links the new record back to the incident. If the action succeeds, we see `Execution_Status__c` update to `'Executed'`. If the recovery action fails due to a callout error, our savepoint logic instantly rolls back all database changes, resets the incident status fields to a triage state, and pushes Slack alerts to operators. We fail safe, every time."

---

## 8. Audit / Replay Explanation
**[Presenter Cue: Open Sentinel Audit Log records]**

**Speaking Script**:  
"Every single transition is documented. Here in `Sentinel_Audit_Log__c`, we see the complete chronological audit trail. Each record logs the exact timestamp, user ID, risk details, and execution decision. A unique Trace UUID connects the entire incident lifecycle. Even if a record is locked or deleted, our referential integrity fallback ensures the GRC compliance log is preserved."

---

## 9. Cost Savings Explanation
**[Presenter Cue: Highlight Cost & Value Insights panel]**

**Speaking Script**:  
"Finally, we translate these operational successes into business value. This Cost & Value panel calculates ROI in real time. By referencing metadata metrics like manual MTTR cost and engineering hourly rates, we see that SentinelFlow has saved this org hours of downtime and avoided customer support cases, generating tangible financial return on investment."

---

## 10. Safety / Governance Message
**Speaking Script**:  
"Our architectural core is built on a clear hierarchy of control: Zentom AI predicts and recommends. SentinelFlow policy controls risk. Human approval controls execution. We strictly prohibit destructive actions like database deletions at the source code layer. Automated healing only operates within safe, pre-approved parameters."

---

## 11. Closing Pitch
**Speaking Script**:  
"By combining proactive predictions, safety gates, and direct financial metrics, SentinelFlow allows your operations teams to scale efficiently while satisfying the most stringent security and compliance requirements. Thank you, and I would love to open the floor to any questions."

---

## 12. Q&A Preparation

### Q1: What happens if the AI makes a false prediction?
- **Answer**: "Zentom AI is a recommendation engine, not an execution engine. It never triggers recovery actions autonomously for high-risk events. If a prediction is noisy, operators simply mark it as 'Noisy' or 'Dismissed', calibrating the weights."

### Q2: How does SentinelFlow prevent infinite execution loops?
- **Answer**: "The engine queries previous execution logs. If an incident registers 3 failed attempts, further executions are blocked immediately with a `RETRY_EXHAUSTED` log, routing it to manual triage."

### Q3: What is the overhead of SentinelFlow on Salesforce governor limits?
- **Answer**: "SentinelFlow executes with strict governor checks. We check for at least 15% headroom of CPU and DML limits before any run. If headroom is insufficient, we defer execution, write a deferral audit log, and dispatch alerts."
