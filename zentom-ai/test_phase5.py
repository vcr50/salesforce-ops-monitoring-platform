import httpx
import json
import time

API = "http://localhost:8000"
ADMIN_KEY = "ztm-admin-key-v1"
SYSTEM_KEY = "ztm-system-key-v1"

def ha(key):
    return {"X-API-Key": key, "Content-Type": "application/json"}

def main():
    time.sleep(4)
    c = httpx.Client(timeout=60.0)

    print("=" * 60)
    print("  PHASE 5 -- OBSERVABILITY & DASHBOARD TEST")
    print("=" * 60)

    # Test 1: Basic health (no auth)
    print("\n[1] GET /health (liveness probe)...")
    r = c.get(f"{API}/health")
    h = r.json()
    print(f"   HTTP {r.status_code}: version={h.get('version')}")
    assert h["version"] == "2.1.0", "Version should be 2.1.0"

    # Test 2: Deep health probe (no auth needed)
    print("\n[2] GET /health/deep (readiness probe)...")
    r = c.get(f"{API}/health/deep")
    d = r.json()
    print(f"   HTTP {r.status_code}: overall={d['status']}")
    for name, info in d.get("subsystems", {}).items():
        lat = info.get("latencyMs", "")
        print(f"   >> {name}: {info['status']}" + (f" ({lat}ms)" if lat else ""))
    assert d["subsystems"]["postgresql"]["status"] == "UP", "PostgreSQL should be UP"

    # Test 3: Analytics with auth
    print("\n[3] GET /analytics/summary (ADMIN)...")
    r = c.get(f"{API}/api/v1/analytics/summary", headers=ha(ADMIN_KEY))
    a = r.json()
    print(f"   HTTP {r.status_code}: workflows={a['totalWorkflows']} success={a['successRate']}")
    assert r.status_code == 200

    # Test 4: Predictions with auth
    print("\n[4] GET /analytics/predictions (ADMIN)...")
    r = c.get(f"{API}/api/v1/analytics/predictions", headers=ha(ADMIN_KEY))
    p = r.json()
    print(f"   HTTP {r.status_code}")
    print(f"   Patterns: {len(p.get('recurringPatterns', []))}")
    print(f"   Risk: {p.get('riskTrend', {}).get('trend')}")
    print(f"   Remediation: {len(p.get('remediationEffectiveness', []))} strategies")
    print(f"   Health: score={p.get('orgHealth', {}).get('score')} grade={p.get('orgHealth', {}).get('grade')}")
    assert r.status_code == 200

    # Test 5: Audit log
    print("\n[5] GET /audit/logs (ADMIN)...")
    r = c.get(f"{API}/api/v1/audit/logs?limit=5", headers=ha(ADMIN_KEY))
    al = r.json()
    print(f"   HTTP {r.status_code}: {len(al.get('logs', []))} entries")
    for log in al.get("logs", [])[:3]:
        print(f"   >> {log['eventType']} | {log['actor']} | {log['resource']}")

    # Test 6: Full orchestration + verify loop
    print("\n[6] Full lifecycle with new observability...")
    r = c.post(f"{API}/api/v1/orchestrate?sync=true", headers=ha(SYSTEM_KEY), json={
        "incidentId": "INC-OBS-TEST",
        "userPrompt": "Apex CPU limit exceeded on batch job",
        "taskType": "GENERAL_DIAGNOSIS",
        "workflowStage": "Triage",
        "mock_arr": 80000.0,
        "mock_error_signature": "Apex CPU limit"
    })
    data = r.json()
    wf_id = data["data"]["agentforcePayload"].get("workflowId")
    print(f"   Workflow #{wf_id}: {data['data']['agentforcePayload']['status']}")

    # Test 7: Check deep health again (embedding model should be loaded now)
    print("\n[7] Deep health after warm-up...")
    r = c.get(f"{API}/health/deep")
    d = r.json()
    em = d["subsystems"]["embeddingModel"]
    print(f"   Embedding model: {em['status']} ({em.get('model', '')})")

    print("\n" + "=" * 60)
    print("  ALL PHASE 5 TESTS PASSED")
    print("=" * 60)

if __name__ == "__main__":
    main()
