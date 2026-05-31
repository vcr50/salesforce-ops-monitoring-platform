import os
import sys
from datetime import datetime, timedelta

# Ensure we can import app modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__))))

from app.models.database import SessionLocal, RecoveryWorkflow

def seed_approvals():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        expires_at = (now + timedelta(hours=2)).isoformat()
        
        # Create a few pending workflows
        w1 = RecoveryWorkflow(
            incident_id="INC-2098",
            proposed_action="Purge Queue",
            confidence=68.5,
            risk_score=75.0,
            policy_reasoning="Risk score (75) exceeds autonomous threshold (50)",
            status="PENDING",
            execution_mode="HUMAN_APPROVAL_REQUIRED",
            created_at=now.isoformat(),
            expires_at=expires_at
        )
        
        w2 = RecoveryWorkflow(
            incident_id="INC-2104",
            proposed_action="Drop Integration Table",
            confidence=95.0,
            risk_score=92.5,
            policy_reasoning="Destructive action requires explicit Human Guardian approval.",
            status="PENDING",
            execution_mode="HUMAN_APPROVAL_REQUIRED",
            created_at=now.isoformat(),
            expires_at=expires_at
        )
        
        db.add(w1)
        db.add(w2)
        db.commit()
        print("Successfully seeded 2 pending workflows!")
    except Exception as e:
        db.rollback()
        print(f"Error seeding workflows: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_approvals()
