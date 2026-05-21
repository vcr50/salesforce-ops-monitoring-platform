import httpx
import json
import asyncio

BASE_URL = "http://localhost:8000/api/v1"

async def main():
    async with httpx.AsyncClient(timeout=30.0) as client:
        
        print("=" * 70)
        print("  ZENTOM AI — FULL END-TO-END TEST")
        print("=" * 70)
        
        # ─── TEST 1: Health Check ─────────────────────────────────
        print("\n[TEST 1] Health Check")
        r = await client.get("http://localhost:8000/health")
        print(f"  Status: {r.status_code}")
        print(f"  Response: {r.json()}")
        
        # ─── TEST 2: Seed Memory with 3 past incidents ───────────
        print("\n[TEST 2] Seeding Memory Engine with resolved incidents...")
        
        incidents_to_seed = [
            {
                "incidentId": "HIST-001",
                "errorSignature": "Stripe OAuth token expired during payment sync",
                "resolution": "Refreshed OAuth token via Token Rotation Scheduler and retried 3 failed payment syncs",
                "confidenceScore": 94.0,
                "wasSuccessful": True
            },
            {
                "incidentId": "HIST-002",
                "errorSignature": "Razorpay webhook 500 Internal Server Error on payment capture",
                "resolution": "Restarted webhook listener service and replayed 12 missed capture events",
                "confidenceScore": 88.0,
                "wasSuccessful": True
            },
            {
                "incidentId": "HIST-003",
                "errorSignature": "SAP ERP integration timeout on order sync batch job",
                "resolution": "Increased batch size timeout from 30s to 120s and split large orders into smaller chunks",
                "confidenceScore": 91.0,
                "wasSuccessful": True
            },
        ]
        
        for inc in incidents_to_seed:
            r = await client.post(f"{BASE_URL}/memory/index", json=inc)
            print(f"  Indexed {inc['incidentId']}: {r.json()}")
        
        # ─── TEST 3: Search Memory for a similar incident ────────
        print("\n[TEST 3] Memory Search — looking for 'OAuth token failure'")
        r = await client.post(f"{BASE_URL}/memory/search", json={
            "errorSignature": "OAuth token failure on Stripe integration",
            "topK": 3
        })
        memory_result = r.json()
        print(f"  Found: {memory_result.get('found')}")
        print(f"  Best Match: {memory_result.get('resolution', 'N/A')}")
        print(f"  Similarity: {memory_result.get('similarity', 'N/A')}")
        
        # ─── TEST 4: Full Orchestration (Async Background Task) ────
        print("\n[TEST 4] Full Orchestration — Stripe OAuth failure (ARR=$150k)")
        r = await client.post(f"{BASE_URL}/orchestrate", json={
            "incidentId": "INC-100",
            "userPrompt": "Stripe integration is failing. OAuth token appears to have expired. Payments are not syncing.",
            "taskType": "GENERAL_DIAGNOSIS",
            "workflowStage": "Triage",
            "mock_arr": 150000.0,
            "mock_error_signature": "OAuth token expired during payment sync"
        })
        
        start_result = r.json()
        print(f"  Start Response: {start_result}")
        task_id = start_result.get("taskId")
        
        # Polling Loop
        if task_id:
            print("  Polling for result...")
            for _ in range(10):
                await asyncio.sleep(1)
                r_status = await client.get(f"{BASE_URL}/orchestrate/status/{task_id}")
                status_res = r_status.json()
                print(f"  Status: {status_res['status']}")
                
                if status_res["status"] == "SUCCESS":
                    result = status_res["data"]
                    print(f"  Selected Model: {result.get('selectedModel')}")
                    print(f"  Decision: {json.dumps(result.get('decision'), indent=4)}")
                    print(f"  Memory Context: {result.get('memoryContext')}")
                    print(f"  Policy: {json.dumps(result.get('policyEvaluation'), indent=4)}")
                    print(f"  Agentforce Payload: {json.dumps(result.get('agentforcePayload'), indent=4)}")
                    break
                elif status_res["status"] == "FAILED":
                    print(f"  Error: {status_res.get('error')}")
                    break
        
        # ─── TEST 5: Low-risk orchestration (Async Polling) ────────
        print("\n[TEST 5] Full Orchestration — Low-risk incident (ARR=$5k)")
        r = await client.post(f"{BASE_URL}/orchestrate", json={
            "incidentId": "INC-101",
            "userPrompt": "Email delivery delayed by 2 minutes on a test sandbox.",
            "taskType": "GENERAL_DIAGNOSIS",
            "workflowStage": "Triage",
            "mock_arr": 5000.0,
            "mock_error_signature": "SendGrid delivery delay"
        })
        task_id_2 = r.json().get("taskId")
        if task_id_2:
            while True:
                await asyncio.sleep(1)
                r_status = await client.get(f"{BASE_URL}/orchestrate/status/{task_id_2}")
                if r_status.json()["status"] == "SUCCESS":
                    result = r_status.json()["data"]
                    print(f"  Selected Model: {result.get('selectedModel')}")
                    print(f"  Execution Mode: {result['agentforcePayload']['executionMode']}")
                    print(f"  Agentforce Ready: {result['agentforcePayload']['agentforceReady']}")
                    break
        
        # ─── TEST 6: Code analysis routing ────────────────────────
        print("\n[TEST 6] Code Analysis — should route to DeepSeek Coder")
        r = await client.post(f"{BASE_URL}/orchestrate", json={
            "incidentId": "INC-102",
            "userPrompt": "Apex trigger failing with null pointer exception on line 42",
            "taskType": "CODE_ANALYSIS",
            "workflowStage": "Diagnosis",
            "mock_arr": 50000.0,
            "mock_error_signature": "NullPointerException in ApexTrigger"
        })
        task_id_3 = r.json().get("taskId")
        if task_id_3:
            while True:
                await asyncio.sleep(1)
                r_status = await client.get(f"{BASE_URL}/orchestrate/status/{task_id_3}")
                if r_status.json()["status"] == "SUCCESS":
                    result = r_status.json()["data"]
                    print(f"  Selected Model: {result.get('selectedModel')}")
                    print(f"  Decision: {result['decision']['recommendation']}")
                    break
        
        # ─── TEST 7: Evaluation feedback ─────────────────────────
        print("\n[TEST 7] Evaluation Feedback — reporting INC-100 success")
        r = await client.post(f"{BASE_URL}/evaluate", json={
            "incidentId": "INC-100",
            "executedAction": "Restart Service",
            "confidenceScore": 92,
            "success": True
        })
        print(f"  Response: {r.json()}")
        
        print("\n" + "=" * 70)
        print("  ALL TESTS COMPLETE")
        print("=" * 70)

if __name__ == "__main__":
    asyncio.run(main())
