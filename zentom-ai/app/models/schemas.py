from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum

class AIModel(str, Enum):
    DEEPSEEK_R1 = "DEEPSEEK_R1"
    AGENTFORCE = "AGENTFORCE"
    LLAMA_3 = "LLAMA_3"
    DEEPSEEK_CODER = "DEEPSEEK_CODER"

class ExecutionMode(str, Enum):
    AUTONOMOUS_EXECUTION = "AUTONOMOUS_EXECUTION"
    HUMAN_APPROVAL_REQUIRED = "HUMAN_APPROVAL_REQUIRED"
    BLOCKED_BY_POLICY = "BLOCKED_BY_POLICY"

class ContextPacket(BaseModel):
    similarIncidents: List[str] = []
    accountARR: float = 0.0
    accountTier: str = "Standard"
    runbookUrl: str = ""
    incidentHistory: str = ""
    errorSignature: str = ""

class RiskScore(BaseModel):
    totalScore: float
    technicalSeverity: float
    businessImpact: float
    blastRadius: float
    operationalContext: float

class PolicyEvaluation(BaseModel):
    mode: ExecutionMode
    policyReasoning: str
    requiresApproval: bool

class ZentomDecision(BaseModel):
    recommendation: str
    confidence_score: int
    proposed_action: str
    rationale: str

class OrchestrateRequest(BaseModel):
    incidentId: str
    userPrompt: str
    taskType: str
    workflowStage: str
    # Mock data for Context Engine since we don't query Salesforce directly from here yet
    mock_arr: float = 150000.0
    mock_error_signature: str = ""
    # Webhook callback URL — if provided, Celery will POST the result here when done
    callbackUrl: Optional[str] = None
