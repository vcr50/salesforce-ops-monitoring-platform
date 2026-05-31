"""
Zentom AI Audit Logger
Structured audit trail for all security-relevant and operational events.
"""
import logging
from datetime import datetime
from app.models.database import SessionLocal, AuditLog

logger = logging.getLogger("zentom.audit")


def log_event(
    event_type: str,
    actor: str,
    actor_role: str = "",
    resource: str = "",
    detail: str = "",
    ip_address: str = "",
    success: bool = True,
    org_id: str = "default",
):
    """
    Persists a structured audit event to PostgreSQL.
    
    Event types:
    - AUTH_SUCCESS / AUTH_FAILURE
    - ORCHESTRATE
    - APPROVE / REJECT
    - VERIFY
    - DRIFT_DETECTED
    - RATE_LIMIT
    """
    db = SessionLocal()
    try:
        entry = AuditLog(
            org_id=org_id,
            timestamp=datetime.utcnow().isoformat(),
            event_type=event_type,
            actor=actor,
            actor_role=actor_role,
            resource=resource,
            detail=detail,
            ip_address=ip_address,
            success=success,
        )
        db.add(entry)
        db.commit()
        
        log_msg = f"[Audit] {event_type} | actor={actor} role={actor_role} resource={resource}"
        if success:
            logger.info(log_msg)
        else:
            logger.warning(log_msg + f" | detail={detail}")
            
    except Exception as e:
        db.rollback()
        logger.error(f"[Audit] Failed to write audit log: {e}")
    finally:
        db.close()


def get_recent_audit_logs(limit: int = 100, org_id: str = "default"):
    """Retrieves recent audit logs for the dashboard."""
    db = SessionLocal()
    try:
        logs = (
            db.query(AuditLog)
            .filter(AuditLog.org_id == org_id)
            .order_by(AuditLog.id.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": log.id,
                "timestamp": log.timestamp,
                "eventType": log.event_type,
                "actor": log.actor,
                "role": log.actor_role,
                "resource": log.resource,
                "detail": log.detail,
                "success": log.success,
            }
            for log in logs
        ]
    finally:
        db.close()
