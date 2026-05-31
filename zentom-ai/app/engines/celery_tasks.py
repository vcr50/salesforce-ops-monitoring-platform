import asyncio
import json
import logging
import httpx
import hmac
import hashlib
from celery import shared_task
from app.models.schemas import ZentomDecision, AIModel, ExecutionMode
from app.engines import context, risk, router, policy, execution, replay
from app.core.config import WEBHOOK_SECRET
from app.core.actions import normalize_action

logger = logging.getLogger("zentom.celery")


@shared_task(bind=True)
def run_orchestration_task(self, request_dict: dict):
    """
    Celery task that wraps the async orchestration pipeline.
    After completion, dispatches the result via webhook callback if a callbackUrl is provided.
    """
    result = asyncio.run(_run_pipeline_async(self.request.id, request_dict))
    
    # ── WEBHOOK DISPATCH ──
    callback_url = request_dict.get("callbackUrl")
    if callback_url and result.get("status") == "SUCCESS":
        asyncio.run(_dispatch_webhook(callback_url, request_dict.get("incidentId", ""), result))
    
    return result


async def _dispatch_webhook(callback_url: str, incident_id: str, result: dict):
    """
    POSTs the orchestration result back to Salesforce (or any webhook receiver).
    Authenticates the payload using HMAC-SHA256 with the shared secret.
    """
    payload = {
        "traceId": result.get("traceId", incident_id),
        "incidentId": incident_id,
        "status": result["status"],
        "decision": result.get("decision"),
        "policyEvaluation": result.get("policyEvaluation"),
        "riskScore": result.get("riskScore"),
        "selectedModel": result.get("selectedModel"),
        "agentforcePayload": result.get("agentforcePayload"),
    }
    
    # ── HMAC Signature ──
    body_bytes = json.dumps(payload, sort_keys=True).encode("utf-8")
    signature = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        body_bytes,
        hashlib.sha256
    ).hexdigest()
    
    headers = {
        "Content-Type": "application/json",
        "X-Zentom-Signature": signature,
        "X-Zentom-Trace-Id": incident_id,
    }
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(callback_url, content=body_bytes, headers=headers)
            logger.info(
                f"[Webhook] Dispatched to {callback_url} — "
                f"HTTP {response.status_code} (incident={incident_id})"
            )
    except Exception as e:
        logger.error(f"[Webhook] Failed to dispatch to {callback_url}: {e}")


async def _run_pipeline_async(task_id: str, request: dict):
    incident_id = request.get("incidentId")
    mock_arr = request.get("mock_arr", 0.0)
    mock_error_signature = request.get("mock_error_signature", "")
    task_type = request.get("taskType", "TRIAGE")
    user_prompt = request.get("userPrompt", "")
    workflow_stage = request.get("workflowStage", "Triage")
    org_id = request.get("org_id", "default")
    
    try:
        # GATE 1: Context Assembly
        ctx_packet = context.assemble_context(
            incident_id=incident_id, 
            mock_arr=mock_arr, 
            mock_error_signature=mock_error_signature,
            org_id=org_id,
        )
        
        # GATE 2: Risk Evaluation
        risk_score = risk.evaluate_risk(incident_id=incident_id, context=ctx_packet)
        
        # ROUTING
        selected_model = router.route(context=ctx_packet, risk=risk_score, task_type=task_type)
        
        enriched_context = (
            f"Account ARR: {ctx_packet.accountARR}\n"
            f"Account Tier: {ctx_packet.accountTier}\n"
            f"Similar Incidents: {'; '.join(ctx_packet.similarIncidents)}\n"
            f"Calculated Risk Score: {risk_score.totalScore}\n"
            f"Selected Model: {selected_model.value}"
        )
        
        # INFERENCE (now with self-healing retries inside groq.py)
        from app.services import groq, ollama
        
        if selected_model == AIModel.DEEPSEEK_R1:
            decision = await groq.call_llama_r1(system_prompt=enriched_context, user_prompt=user_prompt)
        elif selected_model == AIModel.DEEPSEEK_CODER:
            decision = await groq.call_llama_coder(system_prompt=enriched_context, user_prompt=user_prompt)
        elif selected_model == AIModel.LLAMA_3:
            decision = await ollama.call_llama3(system_prompt=enriched_context, user_prompt=user_prompt)
        elif selected_model == AIModel.AGENTFORCE:
            decision = ZentomDecision(
                recommendation="Delegating to Agentforce for native Salesforce record update.",
                confidence_score=100,
                proposed_action="Update Record",
                rationale="Task type is SALESFORCE_RECORD_UPDATE. Agentforce handles this natively in the org."
            )
        else:
            raise ValueError("Invalid model routed.")
        
        decision.proposed_action = normalize_action(decision.proposed_action)
            
        # GATE 3: Policy Validation
        policy_eval = policy.evaluate_action(
            proposed_action=decision.proposed_action, 
            risk_score=risk_score.totalScore, 
            workflow_stage=workflow_stage
        )
        
        # GATE 4: Confidence & AI Guardian Gate
        if decision.confidence_score < 80:
            policy_eval.mode = ExecutionMode.HUMAN_APPROVAL_REQUIRED
            policy_eval.policyReasoning = (
                f"Escalated: Model confidence ({decision.confidence_score}) "
                f"is below the 80% threshold."
            )
        if ctx_packet.accountARR > 50000 and decision.proposed_action != "Escalate":
            policy_eval.mode = ExecutionMode.HUMAN_APPROVAL_REQUIRED
            policy_eval.policyReasoning = (
                "Escalated: Revenue Risk exceeds $50k threshold for autonomous execution."
            )
        
        # GATE 5: Replay Logging
        replay.log_decision(
            incident_id=incident_id,
            context=ctx_packet,
            prompt=user_prompt,
            response=decision.recommendation,
            risk=risk_score,
            policy=policy_eval,
            final_action=decision.proposed_action,
            confidence_score=decision.confidence_score,
            org_id=org_id,
        )
        
        # EXECUTION PREPARATION
        exec_payload = execution.prepare_execution_payload(
            incident_id=incident_id,
            proposed_action=decision.proposed_action,
            confidence_score=decision.confidence_score,
            risk=risk_score,
            mode=policy_eval.mode,
            policy_reasoning=policy_eval.policyReasoning,
            org_id=org_id,
        )
        
        return {
            "status": "SUCCESS",
            "traceId": task_id,
            "decision": decision.model_dump(),
            "policyEvaluation": policy_eval.model_dump(),
            "riskScore": risk_score.model_dump(),
            "selectedModel": selected_model.value,
            "memoryContext": ctx_packet.similarIncidents,
            "agentforcePayload": exec_payload
        }
        
    except Exception as e:
        logger.error(f"[Pipeline] Orchestration failed for {incident_id}: {e}", exc_info=True)
        return {
            "status": "FAILED",
            "traceId": task_id,
            "error": str(e)
        }
