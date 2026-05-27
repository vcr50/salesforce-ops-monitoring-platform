import logging
from datetime import datetime, timedelta
from typing import Dict, Any
from app.models.schemas import RiskScore, ExecutionMode
from app.models.database import SessionLocal, RecoveryWorkflow

logger = logging.getLogger("zentom.execution")

# TTL for pending human approvals (30 minutes)
APPROVAL_TTL_MINUTES = 30


def prepare_execution_payload(
    incident_id: str,
    proposed_action: str,
    confidence_score: int,
    risk: RiskScore,
    mode: ExecutionMode,
    policy_reasoning: str = "",
    org_id: str = "default",
) -> Dict[str, Any]:
    """
    Prepares the execution payload AND persists a RecoveryWorkflow record.
    
    Workflow status is set based on execution mode:
    - AUTONOMOUS_EXECUTION → APPROVED (auto-approved by Policy Engine)
    - HUMAN_APPROVAL_REQUIRED → PENDING (awaiting human decision, 30-min TTL)
    - BLOCKED_BY_POLICY → BLOCKED (no execution possible)
    """
    now = datetime.utcnow()
    
    # Determine initial status and expiry
    if mode == ExecutionMode.AUTONOMOUS_EXECUTION:
        status = "APPROVED"
        expires_at = None
        approved_at = now.isoformat()
        approved_by = "POLICY_ENGINE_AUTO"
    elif mode == ExecutionMode.HUMAN_APPROVAL_REQUIRED:
        status = "PENDING"
        expires_at = (now + timedelta(minutes=APPROVAL_TTL_MINUTES)).isoformat()
        approved_at = None
        approved_by = None
    else:  # BLOCKED_BY_POLICY
        status = "BLOCKED"
        expires_at = None
        approved_at = None
        approved_by = None

    # Persist the workflow
    db = SessionLocal()
    workflow_id = None
    try:
        workflow = RecoveryWorkflow(
            org_id=org_id,
            incident_id=incident_id,
            proposed_action=proposed_action,
            confidence=confidence_score,
            risk_score=risk.totalScore,
            execution_mode=mode.value,
            status=status,
            created_at=now.isoformat(),
            expires_at=expires_at,
            approved_at=approved_at,
            approved_by=approved_by,
            policy_reasoning=policy_reasoning,
        )
        db.add(workflow)
        db.commit()
        db.refresh(workflow)
        workflow_id = workflow.id
        logger.info(
            f"[Execution] Workflow #{workflow_id} created for {incident_id} — "
            f"status={status}, mode={mode.value}"
        )
    except Exception as e:
        db.rollback()
        logger.error(f"[Execution] Failed to persist workflow for {incident_id}: {e}")
    finally:
        db.close()

    payload = {
        "workflowId": workflow_id,
        "incidentId": incident_id,
        "action": proposed_action,
        "confidence": confidence_score,
        "riskScore": risk.totalScore,
        "executionMode": mode.value,
        "agentforceReady": mode == ExecutionMode.AUTONOMOUS_EXECUTION,
        "status": status,
    }

    return payload
