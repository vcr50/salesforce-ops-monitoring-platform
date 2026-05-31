import json
from datetime import datetime
from app.models.schemas import ContextPacket, RiskScore, PolicyEvaluation
from app.models.database import SessionLocal, ReplayLog

def log_decision(
    incident_id: str, 
    context: ContextPacket, 
    prompt: str, 
    response: str, 
    risk: RiskScore, 
    policy: PolicyEvaluation, 
    final_action: str, 
    confidence_score: int,
    org_id: str = "default",
):
    """
    Records the AI decision lifecycle to PostgreSQL for auditability, trust, and evaluation.
    """
    db = SessionLocal()
    try:
        new_log = ReplayLog(
            org_id=org_id,
            incident_id=incident_id,
            timestamp=datetime.utcnow().isoformat(),
            context_snapshot=context.model_dump(),
            llm_prompt=prompt,
            llm_response=response,
            risk_score_snapshot=risk.model_dump(),
            policy_snapshot=policy.model_dump(),
            final_action=final_action,
            confidence_score=confidence_score
        )
        db.add(new_log)
        db.commit()
        print(f"--- ZENTOM REPLAY LOG SAVED TO DB (incident: {incident_id}) ---")
    except Exception as e:
        db.rollback()
        print(f"Error logging replay: {e}")
    finally:
        db.close()

def get_recent_logs(limit: int = 50, org_id: str = "default"):
    """
    Retrieves recent orchestration logs for the monitoring dashboard.
    """
    db = SessionLocal()
    try:
        logs = (
            db.query(ReplayLog)
            .filter(ReplayLog.org_id == org_id)
            .order_by(ReplayLog.id.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": log.id,
                "incident_id": log.incident_id,
                "timestamp": log.timestamp,
                "action": log.final_action,
                "confidence": log.confidence_score,
                "success": True # Mocking success as True for now
            }
            for log in logs
        ]
    finally:
        db.close()
