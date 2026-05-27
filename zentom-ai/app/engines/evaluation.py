from app.models.database import SessionLocal, EvaluationLog

def evaluate_outcome(
    incident_id: str,
    success: bool,
    executed_action: str,
    confidence_score: int,
    org_id: str = "default",
):
    """
    Quality measurement system that judges AI performance.
    Persists evaluation results and detects model drift.
    """
    drift_detected = bool(not success and confidence_score >= 90)
    
    db = SessionLocal()
    try:
        new_eval = EvaluationLog(
            org_id=org_id,
            incident_id=incident_id,
            executed_action=executed_action,
            confidence_score=confidence_score,
            success=success,
            drift_detected=drift_detected
        )
        db.add(new_eval)
        db.commit()
        
        if drift_detected:
            print(f"ALERT: Model Drift Detected! High confidence ({confidence_score}) resulted in failure for {incident_id}.")
        else:
            print(f"Evaluation logged: {incident_id} | Action: {executed_action} | Success: {success}")
    except Exception as e:
        db.rollback()
        print(f"Error logging evaluation: {e}")
    finally:
        db.close()
