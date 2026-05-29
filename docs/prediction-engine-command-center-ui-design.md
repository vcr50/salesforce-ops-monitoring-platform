# Prediction Engine Command Center UI Design (Milestone 54E)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Proposal  
**Version**: 1.0  

---

## 1. Purpose

The purpose of this document is to design the user interface components for displaying prediction cards inside the SentinelFlow Command Center Lightning Web Component (LWC). The primary goal is to surface impending system risks and recommended mitigations to operators in a clear, actionable manner, while enforcing strict visual and textual boundaries showing that the AI **does not autonomously execute actions** without manual clearance.

---

## 2. Prediction Card Layout

Surfaced prediction warnings are modeled as responsive, glassmorphic cards in the UI:

```
┌────────────────────────────────────────────────────────┐
│ 🔴 Prediction Risk Score: 78%        Confidence: 87%   │
├────────────────────────────────────────────────────────┤
│ Summary: Imminent Zoho CRM Integration Failure         │
│                                                        │
│ Why this may happen:                                   │
│ "Outage probability is 78% because a metadata          │
│ deployment occurred 12 minutes ago and HTTP timeout   │
│ counts spiked 4.5x on Zoho CRM endpoint."              │
│                                                        │
│ Signals detected:                                      │
│ [Deployment ⚙️]  [HTTP 500 🌐]                          │
│                                                        │
│ Recommended Mitigation:                                │
│ Suggested Runbook: ZOHO_QUEUE_THROTTLE                 │
│                                                        │
│ ⚠️ Zentom AI predicts possible operational risk.       │
│ No action is executed without policy & human approval. │
├────────────────────────────────────────────────────────┤
│  [ Review Details ]   [ Dismiss ]   [ Approve Runbook ]│
└────────────────────────────────────────────────────────┘
```

### Core UI Sections:
1.  **Risk & Confidence Header**: Large score gauges displaying the calculated `Prediction_Score__c` and `Confidence_Score__c`.
2.  **Summary Header**: Short title explaining the predicted event.
3.  **Explanation Snippet ("Why this may happen")**: Explains the correlation logic in natural language.
4.  **Signals Badges**: Iconized badges showing contributing telemetry signals (e.g., Apex, Flow, Deployment).
5.  **Recommended Mitigation**: Displays the runbook developer key and a brief action guide.
6.  **Action Footer**: Navigation controls and clear safety declarations.

---

## 3. Risk Level Visual States

Cards change visual state dynamically based on the risk probability:

*   **Low Anomaly (< 40%)**: Minimized card. Displayed under a collapsible "Information Logs" tray. Uses neutral gray/green borders.
*   **Potential Anomaly (40 - 70%)**: Warning state. Solid yellow border (`#eab308`) with a static warning icon (`utility:warning`). Displays "Warning: Potential Operational Threat".
*   **Imminent Failure ($\ge 70\%$)**: Critical state. Glowing red border (`#ef4444`) with a pulsing micro-animation. Displays a critical icon (`utility:error`) and "Critical Anomaly: Imminent Outage Risk".

---

## 4. Prediction Explanation Panel

Clicking **Review Details** expands an overlay tray or modal detailing:
*   A timeline view showing exactly when each anomaly signal occurred (e.g. Deployment at 10:15 PM, Spikes at 10:17 PM).
*   A comparison grid showing actual metric values vs average system baselines (e.g. "Zoho Response Time: 4.8s (Baseline: 1.2s)").

---

## 5. Recommended Mitigation Display

*   Suggested runbooks are clearly styled as **suggestions**.
*   The UI displays: *"Suggested Runbook: [Runbook_Key]. Mitigation steps: [Steps_Summary]."*
*   A help tooltip is attached stating: *"Executing this runbook will attempt to proactively mitigate the anomaly. It will not alter system code."*

---

## 6. Operator Actions

Three interactive button controls are available on each card:
1.  **Review Details**: Opens the explanation panel overlay.
2.  **Dismiss**: Prompts the operator for feedback (`Dismiss - False Positive` or `Dismiss - Ignore`) to refine model weights.
3.  **Approve Runbook**: Immediately routes the recommended runbook to the SentinelFlow Gate for execution authorization.

---

## 7. Human Approval Boundary & Safe Wording

To prevent user confusion regarding autonomous actions, the UI enforces strict wording rules:

*   **Required Safety Footer** (Visible on every prediction card):
    > ⚠️ **Zentom AI predicts possible operational risk. No action is executed without policy and human approval.**
*   **Prohibited Wording**:
    *   *Do NOT use*: "AI will prevent this automatically"
    *   *Do NOT use*: "AI will execute prediction fix"
    *   *Do NOT use*: "Auto-fixing outage..."

---

## 8. Dashboard Placement

*   **Section Header**: "Predictive Operational Intelligence"
*   **Grid Placement**: Plotted directly below the "Estimated Value Realization" widgets and above the "Live Traffic Board" table.
*   **Flex Wrap Grid**: Displays cards in a side-by-side card container, resizing responsively to 1, 2, or 3 columns depending on screens.

---

## 9. Empty & Error States

*   **Empty State (Stable System)**:
    - Displayed when no active predictions exceed 40%.
    - Shows a checkmark icon with the copy: *"No imminent operational risks predicted. The SentinelFlow system is stable."*
*   **Error State (Query Failure)**:
    - Displayed if the background scoring engine fails or encounters quotas.
    - Shows a warning box with the copy: *"Failed to retrieve predictive telemetry. Dynamic polling fallback active."*

---

## 10. Success Criteria

- [ ] Clear separation between "Suggested Runbooks" and "Executed Actions".
- [ ] No automated execution of proactive runbooks without human confirmation.
- [ ] Wording strictly conforms to safe terminology guidelines.
