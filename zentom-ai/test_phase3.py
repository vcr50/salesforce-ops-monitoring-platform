import httpx
import json
import time

API = "http://localhost:8000/api/v1"
ADMIN_KEY = "ztm-admin-key-v1"
OPERATOR_KEY = "ztm-operator-key-v1"
SYSTEM_KEY = "ztm-system-key-v1"
INVALID_KEY = "ztm-FAKE-KEY-999"

def h(key):
    return {"X-API-Key": key, "Content-Type": "application/json"}

def main():
    # Wait for server
    time.sleep(3)
    c = httpx.Client(timeout=60.0)

    print("=" * 60)
    print("  PHASE 3 -- SECURITY & RBAC TEST")
    print("=" * 60)

    # ── Test 1: Health is exempt (no key needed) ──
    print("\n[1] /health (no auth required)...")
    r = c.get("http://localhost:8000/health")
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 200, "FAIL: health should be public"

    # ── Test 2: No API key -> 401 ──
    print("\n[2] /analytics/summary (no key) -> expect 401...")
    r = c.get(f"{API}/analytics/summary")
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 401, "FAIL: should reject missing key"

    # ── Test 3: Invalid API key -> 403 ──
    print("\n[3] /analytics/summary (invalid key) -> expect 403...")
    r = c.get(f"{API}/analytics/summary", headers=h(INVALID_KEY))
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 403, "FAIL: should reject invalid key"

    # ── Test 4: Operator can access analytics ──
    print("\n[4] /analytics/summary (OPERATOR key) -> expect 200...")
    r = c.get(f"{API}/analytics/summary", headers=h(OPERATOR_KEY))
    print(f"   HTTP {r.status_code}: OK")
    assert r.status_code == 200, "FAIL: operator should access analytics"

    # ── Test 5: Operator CANNOT orchestrate (requires SYSTEM) ──
    print("\n[5] /orchestrate (OPERATOR key) -> expect 403...")
    r = c.post(f"{API}/orchestrate?sync=true", headers=h(OPERATOR_KEY), json={
        "incidentId": "TEST", "userPrompt": "test", "taskType": "TRIAGE", "workflowStage": "Triage"
    })
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 403, "FAIL: operator should not orchestrate"

    # ── Test 6: System key CAN orchestrate ──
    print("\n[6] /orchestrate (SYSTEM key, sync) -> expect 200...")
    r = c.post(f"{API}/orchestrate?sync=true", headers=h(SYSTEM_KEY), json={
        "incidentId": "INC-SEC-TEST",
        "userPrompt": "SOQL timeout on Account query",
        "taskType": "GENERAL_DIAGNOSIS",
        "workflowStage": "Triage",
        "mock_arr": 150000.0,
        "mock_error_signature": "SOQL timeout"
    })
    print(f"   HTTP {r.status_code}: {r.json().get('status')}")
    assert r.status_code == 200, "FAIL: system key should orchestrate"
    wf_id = r.json()["data"]["agentforcePayload"].get("workflowId")
    print(f"   Workflow ID: {wf_id}")

    # ── Test 7: Operator CANNOT approve (requires ADMIN) ──
    print(f"\n[7] /approvals/{wf_id}/approve (OPERATOR key) -> expect 403...")
    r = c.post(f"{API}/approvals/{wf_id}/approve", headers=h(OPERATOR_KEY), json={"approved_by": "op1"})
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 403, "FAIL: operator should not approve"

    # ── Test 8: Admin CAN approve ──
    print(f"\n[8] /approvals/{wf_id}/approve (ADMIN key) -> expect 200...")
    r = c.post(f"{API}/approvals/{wf_id}/approve", headers=h(ADMIN_KEY), json={"approved_by": "CTO"})
    print(f"   HTTP {r.status_code}: {r.json()}")
    assert r.status_code == 200, "FAIL: admin should approve"

    # ── Test 9: Admin can view audit logs ──
    print("\n[9] /audit/logs (ADMIN key) -> expect 200...")
    r = c.get(f"{API}/audit/logs", headers=h(ADMIN_KEY))
    audit = r.json()
    print(f"   HTTP {r.status_code}: {len(audit['logs'])} audit entries")
    for log in audit["logs"][:5]:
        print(f"   >> {log['eventType']} | {log['actor']} ({log['role']}) | {log['resource']}")

    print("\n" + "=" * 60)
    print("  ALL PHASE 3 SECURITY TESTS PASSED")
    print("=" * 60)

if __name__ == "__main__":
    main()
