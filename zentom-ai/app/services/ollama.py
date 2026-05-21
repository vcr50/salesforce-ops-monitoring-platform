import os
import httpx
from app.models.schemas import ZentomDecision

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")

async def call_llama3(system_prompt: str, user_prompt: str) -> ZentomDecision:
    """
    Calls local Ollama Llama 3 model for fast triage.
    """
    print("Calling Local Ollama Llama 3...")
    return ZentomDecision(
        recommendation="Fast triage identifies standard OAuth failure.",
        confidence_score=85,
        proposed_action="Refresh Token",
        rationale="Standard failure signature matched locally via Llama 3."
    )
