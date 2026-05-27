from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
from app.models.schemas import OrchestrateRequest, ZentomDecision, AIModel
from app.engines import context, risk, router, policy, execution, replay, evaluation, memory
from app.core.audit import log_event

api_router = APIRouter()

# ─── Memory Indexing ───────────────────────────────────────────────

class MemoryIndexRequest(BaseModel):
    incidentId: str
    errorSignature: str
    resolution: str
    confidenceScore: float = 0.0
    wasSuccessful: bool = True

@api_router.post("/memory/index")
async def index_memory(request: MemoryIndexRequest, req: Request):
    """Index a resolved incident into the Memory Engine for future RAG retrieval."""
    result = memory.index_incident(
        incident_id=request.incidentId,
        error_signature=request.errorSignature,
        resolution=request.resolution,
        confidence_score=request.confidenceScore,
        was_successful=request.wasSuccessful,
        org_id=getattr(req.state, "org_id", "default"),
    )
    return result


class MemorySearchRequest(BaseModel):
    errorSignature: str
    topK: int = 3

@api_router.post("/memory/search")
async def search_memory(request: MemorySearchRequest, req: Request):
    """Search the Memory Engine for similar past incidents."""
    result = memory.retrieve_memory(
        request.errorSignature,
        top_k=request.topK,
        org_id=getattr(req.state, "org_id", "default"),
    )
    return result


# ─── Evaluation Feedback ──────────────────────────────────────────

class EvaluateRequest(BaseModel):
    incidentId: str
    executedAction: str
    confidenceScore: int
    success: bool

@api_router.post("/evaluate")
async def evaluate_outcome(request: EvaluateRequest, req: Request):
    """Receive execution outcome feedback from Salesforce to track AI performance."""
    evaluation.evaluate_outcome(
        incident_id=request.incidentId,
        success=request.success,
        executed_action=request.executedAction,
        confidence_score=request.confidenceScore,
        org_id=getattr(req.state, "org_id", "default"),
    )
    return {"status": "evaluated", "incidentId": request.incidentId}


# ─── Master Orchestration ─────────────────────────────────────────

@api_router.post("/orchestrate", status_code=202)
async def orchestrate_incident(request: OrchestrateRequest, req: Request, sync: bool = False):
    """
    Kicks off the master orchestration pipeline.
    
    Modes:
    - sync=False (default): Dispatches to Celery and returns a Task ID immediately.
      If request includes a callbackUrl, Celery will POST the result there when done.
    - sync=True: Runs the pipeline inline and returns the full result (for dev/testing).
    """
    from app.engines.celery_tasks import run_orchestration_task, _run_pipeline_async
    payload = request.model_dump()
    payload["org_id"] = getattr(req.state, "org_id", "default")
    
    if sync:
        result = await _run_pipeline_async("sync-task", payload)
        if result.get("status") == "SUCCESS":
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=200, content={"status": "SUCCESS", "data": result})
        else:
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=500, content={"status": "FAILED", "error": result.get("error", "Unknown")})
            
    # Fire via Celery
    task = run_orchestration_task.delay(payload)
    log_event(
        "ORCHESTRATE",
        actor=getattr(req.state, 'api_key_name', 'unknown'),
        actor_role=getattr(req.state, 'api_key_role', ''),
        resource=request.incidentId,
        detail=f"taskId={task.id}",
        org_id=getattr(req.state, "org_id", "default"),
    )
    return {"status": "ACCEPTED", "taskId": task.id}


@api_router.get("/orchestrate/status/{task_id}")
async def get_orchestration_status(task_id: str):
    """Poll for the result of the Celery background task."""
    from celery.result import AsyncResult
    from app.core.celery_app import celery_app
    
    task_result = AsyncResult(task_id, app=celery_app)
    
    if task_result.state == "SUCCESS":
        res = task_result.result
        if res.get("status") == "SUCCESS":
            task_result.forget()
            return {"status": "SUCCESS", "data": res}
        else:
            task_result.forget()
            return {"status": "FAILED", "error": res.get("error", "Unknown")}
    elif task_result.state == "FAILURE":
        task_result.forget()
        return {"status": "FAILED", "error": str(task_result.info)}
    else:
        return {"status": task_result.state}


# ─── Dashboard Metrics ────────────────────────────────────────────

@api_router.get("/metrics")
async def get_metrics(req: Request):
    """Returns dashboard metrics and recent orchestration logs."""
    from app.engines.replay import get_recent_logs
    logs = get_recent_logs(50, org_id=getattr(req.state, "org_id", "default"))
    
    total_incidents = len(logs)
    successes = sum(1 for log in logs if log["success"])
    success_rate = (successes / total_incidents * 100) if total_incidents > 0 else 0
    
    return {
        "total_processed": total_incidents,
        "success_rate": f"{success_rate:.1f}%",
        "recent_logs": logs
    }


# ─── Human Approval Queue ─────────────────────────────────────────

@api_router.get("/approvals/pending")
async def get_pending_approvals(req: Request):
    """Returns all workflows awaiting human approval. Expired ones are auto-marked."""
    from datetime import datetime
    from app.models.database import SessionLocal, RecoveryWorkflow
    
    db = SessionLocal()
    try:
        org_id = getattr(req.state, "org_id", "default")
        # First, expire any overdue PENDING workflows
        now = datetime.utcnow().isoformat()
        expired = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.org_id == org_id)
            .filter(RecoveryWorkflow.status == "PENDING")
            .filter(RecoveryWorkflow.expires_at != None)
            .filter(RecoveryWorkflow.expires_at < now)
            .all()
        )
        for wf in expired:
            wf.status = "EXPIRED"
        if expired:
            db.commit()
        
        # Now fetch remaining PENDING workflows
        pending = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.org_id == org_id)
            .filter(RecoveryWorkflow.status == "PENDING")
            .order_by(RecoveryWorkflow.created_at.desc())
            .all()
        )
        
        return {
            "count": len(pending),
            "expired_count": len(expired),
            "workflows": [
                {
                    "workflowId": wf.id,
                    "incidentId": wf.incident_id,
                    "proposedAction": wf.proposed_action,
                    "confidence": wf.confidence,
                    "riskScore": wf.risk_score,
                    "policyReasoning": wf.policy_reasoning,
                    "createdAt": wf.created_at,
                    "expiresAt": wf.expires_at,
                }
                for wf in pending
            ],
        }
    finally:
        db.close()


class ApprovalAction(BaseModel):
    approved_by: str


@api_router.post("/approvals/{workflow_id}/approve")
async def approve_workflow(workflow_id: int, action: ApprovalAction, req: Request):
    """Approve a pending workflow for execution."""
    from datetime import datetime
    from app.models.database import SessionLocal, RecoveryWorkflow
    
    db = SessionLocal()
    try:
        org_id = getattr(req.state, "org_id", "default")
        wf = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.id == workflow_id)
            .filter(RecoveryWorkflow.org_id == org_id)
            .first()
        )
        
        if not wf:
            raise HTTPException(status_code=404, detail=f"Workflow #{workflow_id} not found")
        
        if wf.status != "PENDING":
            raise HTTPException(
                status_code=409,
                detail=f"Workflow #{workflow_id} is '{wf.status}' and cannot be approved."
            )
        
        # Check TTL expiry
        now = datetime.utcnow()
        if wf.expires_at and datetime.fromisoformat(wf.expires_at) < now:
            wf.status = "EXPIRED"
            db.commit()
            raise HTTPException(status_code=410, detail="Workflow expired. TTL exceeded.")
        
        wf.status = "APPROVED"
        wf.approved_at = now.isoformat()
        wf.approved_by = action.approved_by
        db.commit()
        
        log_event("APPROVE", actor=action.approved_by, actor_role=getattr(req.state, 'api_key_role', ''), resource=str(workflow_id), detail=f"incident={wf.incident_id} action={wf.proposed_action}", org_id=org_id)
        return {
            "workflowId": workflow_id,
            "status": "APPROVED",
            "approvedBy": action.approved_by,
            "incidentId": wf.incident_id,
            "action": wf.proposed_action,
        }
    finally:
        db.close()


class RejectAction(BaseModel):
    reason: str


@api_router.post("/approvals/{workflow_id}/reject")
async def reject_workflow(workflow_id: int, action: RejectAction, req: Request):
    """Reject a pending workflow."""
    from datetime import datetime
    from app.models.database import SessionLocal, RecoveryWorkflow
    
    db = SessionLocal()
    try:
        org_id = getattr(req.state, "org_id", "default")
        wf = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.id == workflow_id)
            .filter(RecoveryWorkflow.org_id == org_id)
            .first()
        )
        
        if not wf:
            raise HTTPException(status_code=404, detail=f"Workflow #{workflow_id} not found")
        
        if wf.status != "PENDING":
            raise HTTPException(
                status_code=409,
                detail=f"Workflow #{workflow_id} is '{wf.status}' and cannot be rejected."
            )
        
        wf.status = "REJECTED"
        wf.rejected_reason = action.reason
        db.commit()
        
        log_event("REJECT", actor=getattr(req.state, 'api_key_name', 'unknown'), actor_role=getattr(req.state, 'api_key_role', ''), resource=str(workflow_id), detail=f"reason={action.reason}", org_id=org_id)
        return {
            "workflowId": workflow_id,
            "status": "REJECTED",
            "reason": action.reason,
        }
    finally:
        db.close()


# ─── Verification ─────────────────────────────────────────────────

class VerifyRequest(BaseModel):
    success: bool
    details: str = ""


@api_router.post("/verify/{workflow_id}")
async def verify_workflow(workflow_id: int, request: VerifyRequest, req: Request):
    """Post-execution verification. Closes the recovery loop."""
    from app.engines.verification import verify_execution
    
    result = verify_execution(
        workflow_id=workflow_id,
        success=request.success,
        details=request.details,
        org_id=getattr(req.state, "org_id", "default"),
    )
    
    if not result.get("verified"):
        raise HTTPException(status_code=400, detail=result.get("error", "Verification failed"))
    
    return result


# ─── Operational Analytics ─────────────────────────────────────────

@api_router.get("/analytics/summary")
async def get_analytics_summary(req: Request):
    """
    Returns computed operational analytics:
    - Total incidents, success rate, avg confidence
    - Model drift count
    - Approval queue depth
    - MTTR (mean time to resolution)
    - Breakdown by execution mode
    """
    from datetime import datetime
    from app.models.database import SessionLocal, RecoveryWorkflow, EvaluationLog, ReplayLog
    from sqlalchemy import func
    
    db = SessionLocal()
    try:
        org_id = getattr(req.state, "org_id", "default")
        # ── Total workflows ──
        total_workflows = db.query(func.count(RecoveryWorkflow.id)).filter(RecoveryWorkflow.org_id == org_id).scalar() or 0
        
        # ── Status breakdown ──
        status_counts = dict(
            db.query(RecoveryWorkflow.status, func.count(RecoveryWorkflow.id))
            .filter(RecoveryWorkflow.org_id == org_id)
            .group_by(RecoveryWorkflow.status)
            .all()
        )
        
        # ── Execution mode breakdown ──
        mode_counts = dict(
            db.query(RecoveryWorkflow.execution_mode, func.count(RecoveryWorkflow.id))
            .filter(RecoveryWorkflow.org_id == org_id)
            .group_by(RecoveryWorkflow.execution_mode)
            .all()
        )
        
        # ── Evaluation metrics ──
        total_evaluated = db.query(func.count(EvaluationLog.id)).filter(EvaluationLog.org_id == org_id).scalar() or 0
        total_successes = (
            db.query(func.count(EvaluationLog.id))
            .filter(EvaluationLog.org_id == org_id)
            .filter(EvaluationLog.success == True)
            .scalar() or 0
        )
        drift_count = (
            db.query(func.count(EvaluationLog.id))
            .filter(EvaluationLog.org_id == org_id)
            .filter(EvaluationLog.drift_detected == True)
            .scalar() or 0
        )
        avg_confidence = (
            db.query(func.avg(ReplayLog.confidence_score))
            .filter(ReplayLog.org_id == org_id)
            .scalar() or 0
        )
        
        # ── Approval queue depth ──
        pending_approvals = (
            db.query(func.count(RecoveryWorkflow.id))
            .filter(RecoveryWorkflow.org_id == org_id)
            .filter(RecoveryWorkflow.status == "PENDING")
            .scalar() or 0
        )
        
        # ── MTTR (Mean Time To Resolution) ──
        resolved = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.org_id == org_id)
            .filter(RecoveryWorkflow.status == "RESOLVED")
            .filter(RecoveryWorkflow.verified_at != None)
            .all()
        )
        
        mttr_seconds = 0
        if resolved:
            total_delta = 0
            for wf in resolved:
                try:
                    created = datetime.fromisoformat(wf.created_at)
                    verified = datetime.fromisoformat(wf.verified_at)
                    total_delta += (verified - created).total_seconds()
                except (ValueError, TypeError):
                    continue
            mttr_seconds = total_delta / len(resolved) if resolved else 0
        
        success_rate = (total_successes / total_evaluated * 100) if total_evaluated > 0 else 0
        
        return {
            "totalWorkflows": total_workflows,
            "totalEvaluated": total_evaluated,
            "successRate": f"{success_rate:.1f}%",
            "avgConfidence": round(avg_confidence, 1),
            "driftAlerts": drift_count,
            "pendingApprovals": pending_approvals,
            "mttrSeconds": round(mttr_seconds, 1),
            "statusBreakdown": status_counts,
            "modeBreakdown": mode_counts,
        }
    finally:
        db.close()

# ─── Audit Logs ───────────────────────────────────────────────────

@api_router.get("/audit/logs")
async def get_audit_logs(req: Request, limit: int = 100):
    """Returns recent audit log entries. Requires ADMIN role."""
    from app.core.audit import get_recent_audit_logs
    return {"logs": get_recent_audit_logs(limit, org_id=getattr(req.state, "org_id", "default"))}


# ─── Predictive Intelligence ─────────────────────────────────────

@api_router.get("/analytics/predictions")
async def get_predictions(req: Request):
    """
    Returns predictive operational intelligence:
    - Recurring incident patterns
    - Risk trend analysis
    - Remediation effectiveness scores
    - Predicted next actions
    - Org health score
    """
    from app.engines.predictive import generate_predictions
    org_id = getattr(req.state, "org_id", "default")
    return generate_predictions(org_id)


# ─── Cross-Org Shared Memory ─────────────────────────────────────

class ShareMemoryRequest(BaseModel):
    memoryId: int


@api_router.post("/memory/share")
async def share_memory_cross_org(request: ShareMemoryRequest, req: Request):
    """
    Share a resolved incident memory to the cross-org pool.
    Other orgs can then benefit from this resolution pattern.
    """
    from app.models.database import SessionLocal, IncidentMemory
    org_id = getattr(req.state, "org_id", "default")

    db = SessionLocal()
    try:
        mem = (
            db.query(IncidentMemory)
            .filter(IncidentMemory.id == request.memoryId)
            .filter(IncidentMemory.org_id == org_id)
            .first()
        )
        if not mem:
            raise HTTPException(status_code=404, detail="Memory not found in your org")
        if mem.shared:
            return {"status": "already_shared", "memoryId": mem.id}

        mem.shared = True
        db.commit()
        log_event("MEMORY_SHARE", actor=getattr(req.state, "api_key_name", "unknown"),
                  actor_role=getattr(req.state, "api_key_role", ""),
                  resource=str(mem.id), detail=f"Shared to cross-org pool: {mem.error_signature[:60]}")
        return {"status": "shared", "memoryId": mem.id, "errorSignature": mem.error_signature}
    finally:
        db.close()


@api_router.post("/memory/search/cross-org")
async def search_cross_org_memory(request: MemorySearchRequest, req: Request):
    """
    Search memory across all orgs (shared pool only).
    Returns matches from own org first, then shared cross-org matches.
    """
    from app.engines.memory import generate_embedding
    from app.models.database import SessionLocal, IncidentMemory
    from sqlalchemy import or_

    org_id = getattr(req.state, "org_id", "default")
    query_embedding = generate_embedding(request.errorSignature)

    db = SessionLocal()
    try:
        # Search: own org OR shared=True from any org
        results = (
            db.query(
                IncidentMemory,
                IncidentMemory.embedding.cosine_distance(query_embedding).label("distance")
            )
            .filter(IncidentMemory.was_successful == True)
            .filter(
                or_(
                    IncidentMemory.org_id == org_id,
                    IncidentMemory.shared == True
                )
            )
            .order_by(IncidentMemory.embedding.cosine_distance(query_embedding))
            .limit(request.topK)
            .all()
        )

        matches = []
        for match, distance in results:
            similarity = 1 - distance
            if similarity >= 0.3:
                matches.append({
                    "memoryId": match.id,
                    "orgId": match.org_id,
                    "isOwnOrg": match.org_id == org_id,
                    "isShared": match.shared,
                    "errorSignature": match.error_signature,
                    "resolution": match.resolution,
                    "similarity": round(similarity, 4),
                    "confidence": match.confidence_score,
                })

        return {
            "totalMatches": len(matches),
            "ownOrgMatches": sum(1 for m in matches if m["isOwnOrg"]),
            "crossOrgMatches": sum(1 for m in matches if not m["isOwnOrg"]),
            "matches": matches,
        }
    finally:
        db.close()
