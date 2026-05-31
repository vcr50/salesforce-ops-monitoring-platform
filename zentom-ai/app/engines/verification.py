import logging
from datetime import datetime
from app.models.database import SessionLocal, RecoveryWorkflow

logger = logging.getLogger("zentom.verification")


def verify_execution(workflow_id: int, success: bool, details: str = "", org_id: str = "default") -> dict:
    """
    Post-execution verification. Closes the recovery workflow loop.
    
    Updates the workflow status to RESOLVED or FAILED based on the outcome.
    If a high-confidence action failed, flags it as DRIFT_DETECTED.
    """
    db = SessionLocal()
    try:
        workflow = (
            db.query(RecoveryWorkflow)
            .filter(RecoveryWorkflow.id == workflow_id)
            .filter(RecoveryWorkflow.org_id == org_id)
            .first()
        )
        
        if not workflow:
            return {"error": f"Workflow #{workflow_id} not found", "verified": False}
        
        if workflow.status not in ("APPROVED", "EXECUTING", "VERIFYING"):
            return {
                "error": f"Workflow #{workflow_id} is in status '{workflow.status}' and cannot be verified.",
                "verified": False,
            }
        
        now = datetime.utcnow().isoformat()
        
        # Drift detection: high confidence + failure = model drift
        drift_detected = not success and workflow.confidence >= 85
        
        if success:
            workflow.status = "RESOLVED"
            workflow.verification_result = "SUCCESS"
        elif drift_detected:
            workflow.status = "FAILED"
            workflow.verification_result = "DRIFT_DETECTED"
            logger.warning(
                f"[Verification] DRIFT DETECTED — Workflow #{workflow_id} "
                f"(incident={workflow.incident_id}) failed with confidence={workflow.confidence}. "
                f"Details: {details}"
            )
        else:
            workflow.status = "FAILED"
            workflow.verification_result = "FAILED"
        
        workflow.verified_at = now
        db.commit()
        
        logger.info(
            f"[Verification] Workflow #{workflow_id} → {workflow.status} "
            f"(result={workflow.verification_result})"
        )
        
        return {
            "workflowId": workflow_id,
            "incidentId": workflow.incident_id,
            "status": workflow.status,
            "verificationResult": workflow.verification_result,
            "driftDetected": drift_detected,
            "verified": True,
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"[Verification] Error verifying workflow #{workflow_id}: {e}")
        return {"error": str(e), "verified": False}
    finally:
        db.close()
