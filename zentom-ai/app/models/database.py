from sqlalchemy import create_engine, text, Column, Integer, String, Float, Boolean, JSON
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://zentom_user:zentom_password@localhost:5432/zentom_db")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

from pgvector.sqlalchemy import Vector

class IncidentMemory(Base):
    __tablename__ = "incident_memory"
    
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(String, nullable=False, default="default", index=True)  # tenant isolation
    incident_id = Column(String, nullable=False)
    error_signature = Column(String, nullable=False)
    resolution = Column(String, nullable=False)
    confidence_score = Column(Float, default=0.0)
    was_successful = Column(Boolean, default=True)
    shared = Column(Boolean, default=False)  # cross-org shared memory
    # Using pgvector! We know all-MiniLM-L6-v2 outputs 384-dimensional embeddings
    embedding = Column(Vector(384))

class ReplayLog(Base):
    __tablename__ = "replay_log"
    
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(String, nullable=False, default="default", index=True)
    incident_id = Column(String, nullable=False)
    timestamp = Column(String, nullable=False)
    context_snapshot = Column(JSON)
    llm_prompt = Column(String)
    llm_response = Column(String)
    risk_score_snapshot = Column(JSON)
    policy_snapshot = Column(JSON)
    final_action = Column(String)
    confidence_score = Column(Integer)

class EvaluationLog(Base):
    __tablename__ = "evaluation_log"
    
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(String, nullable=False, default="default", index=True)
    incident_id = Column(String, nullable=False)
    executed_action = Column(String, nullable=False)
    confidence_score = Column(Integer)
    success = Column(Boolean)
    drift_detected = Column(Boolean)

class RecoveryWorkflow(Base):
    __tablename__ = "recovery_workflow"
    
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(String, nullable=False, default="default", index=True)
    incident_id = Column(String, nullable=False, index=True)
    proposed_action = Column(String, nullable=False)
    confidence = Column(Integer, nullable=False)
    risk_score = Column(Float, nullable=False)
    execution_mode = Column(String, nullable=False)
    status = Column(String, nullable=False, default="PENDING")
    created_at = Column(String, nullable=False)
    expires_at = Column(String, nullable=True)
    approved_at = Column(String, nullable=True)
    approved_by = Column(String, nullable=True)
    rejected_reason = Column(String, nullable=True)
    executed_at = Column(String, nullable=True)
    verified_at = Column(String, nullable=True)
    verification_result = Column(String, nullable=True)
    policy_reasoning = Column(String, nullable=True)

class AuditLog(Base):
    __tablename__ = "audit_log"
    
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(String, nullable=False, default="default", index=True)
    timestamp = Column(String, nullable=False)
    event_type = Column(String, nullable=False, index=True)
    actor = Column(String, nullable=False)
    actor_role = Column(String, nullable=True)
    resource = Column(String, nullable=True)
    detail = Column(String, nullable=True)
    ip_address = Column(String, nullable=True)
    success = Column(Boolean, default=True)

def init_db():
    """Initialize the PostgreSQL database and ensure pgvector is enabled."""
    try:
        with engine.connect() as conn:
            conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
            conn.commit()
            print("Successfully verified/created 'vector' extension in PostgreSQL.")
            
        # Create all tables (including vector columns)
        Base.metadata.create_all(bind=engine)
        print(f"Database initialized at {DATABASE_URL}")
    except Exception as e:
        print(f"Failed to connect to PostgreSQL: {e}")
        print("Please ensure Docker container 'zentom-pgvector' is running.")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
