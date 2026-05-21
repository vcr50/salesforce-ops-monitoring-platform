import httpx
import json

API = "http://localhost:8000/api/v1"

def main():
    c = httpx.Client(timeout=60.0)

    print("=" * 60)
    print("  PHASE 2 — FULL LIFECYCLE TEST")
    print("=" * 60)

    # Step 1: Submit high-ARR incident
    print("\n[1] Submitting incident (ARR=$150k -> HUMAN_APPROVAL_REQUIRED)...")
    r = c.post(f"{API}/orchestrate?sync=true", json={
        "incidentId": "INC-PHASE2-001",
        "userPrompt": "Payment gateway timeout on Stripe integration",
        "taskType": "GENERAL_DIAGNOSIS",
        "workflowStage": "Triage",
        "mock_arr": 150000.0,
        "mock_error_signature": "Stripe gateway timeout"
    })
    data = r.json()
    print(f"   HTTP: {r.status_code}")
    print(f"   Status: {data['status']}")
    af = data["data"]["agentforcePayload"]
    wf_id = af.get("workflowId")
    print(f"   Workflow ID: {wf_id}")
    print(f"   Workflow Status: {af.get('status')}")
    print(f"   agentforceReady: {af.get('agentforceReady')}")

    # Step 2: Check approval queue
    print("\n[2] Checking approval queue...")
    r = c.get(f"{API}/approvals/pending")
    approvals = r.json()
    print(f"   Pending count: {approvals['count']}")
    if approvals["count"] > 0:
        wf = approvals["workflows"][0]
        print(f"   First: #{wf['workflowId']} — {wf['proposedAction']} ({wf['confidence']}%)")
        print(f"   Policy: {wf['policyReasoning']}")

    # Step 3: Approve
    print(f"\n[3] Approving workflow #{wf_id}...")
    r = c.post(f"{API}/approvals/{wf_id}/approve", json={"approved_by": "CTO_Admin"})
    print(f"   Result: {r.json()}")

    # Step 4: Verify (success)
    print(f"\n[4] Verifying workflow #{wf_id} (success)...")
    r = c.post(f"{API}/verify/{wf_id}", json={"success": True, "details": "Payment gateway recovered."})
    print(f"   Result: {r.json()}")

    # Step 5: Analytics
    print("\n[5] Checking analytics summary...")
    r = c.get(f"{API}/analytics/summary")
    a = r.json()
    print(f"   Total Workflows: {a['totalWorkflows']}")
    print(f"   Success Rate: {a['successRate']}")
    print(f"   Avg Confidence: {a['avgConfidence']}")
    print(f"   Drift Alerts: {a['driftAlerts']}")
    print(f"   Pending Approvals: {a['pendingApprovals']}")
    print(f"   MTTR: {a['mttrSeconds']}s")
    print(f"   Status Breakdown: {a['statusBreakdown']}")
    print(f"   Mode Breakdown: {a['modeBreakdown']}")

    # Step 6: Test drift detection (high confidence + failure)
    print("\n[6] Testing drift detection (submit low-ARR, then verify as FAILED)...")
    r = c.post(f"{API}/orchestrate?sync=true", json={
        "incidentId": "INC-DRIFT-TEST",
        "userPrompt": "Minor email delay on sandbox",
        "taskType": "GENERAL_DIAGNOSIS",
        "workflowStage": "Triage",
        "mock_arr": 5000.0,
        "mock_error_signature": "SendGrid delay"
    })
    data2 = r.json()
    wf_id2 = data2["data"]["agentforcePayload"].get("workflowId")
    conf2 = data2["data"]["decision"]["confidence_score"]
    print(f"   Workflow #{wf_id2}, confidence={conf2}")

    r = c.post(f"{API}/verify/{wf_id2}", json={"success": False, "details": "Action did not resolve the issue."})
    vr = r.json()
    print(f"   Verification: {vr}")
    print(f"   Drift Detected: {vr.get('driftDetected')}")

    # Final analytics
    print("\n[7] Final analytics...")
    r = c.get(f"{API}/analytics/summary")
    a = r.json()
    print(f"   Total Workflows: {a['totalWorkflows']}")
    print(f"   Status Breakdown: {a['statusBreakdown']}")
    print(f"   MTTR: {a['mttrSeconds']}s")

    print("\n" + "=" * 60)
    print("  ALL PHASE 2 TESTS COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    main()
