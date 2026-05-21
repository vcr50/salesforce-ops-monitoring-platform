import os
import json
import httpx
from app.models.schemas import ZentomDecision
from app.core.config import DEEPSEEK_API_KEY, DEEPSEEK_API_URL

# The Zentom system prompt from ZentomAIClient.cls
ZENTOM_SYSTEM_PROMPT = (
    "You are the Zentom Orchestration System LLM, the central reasoning and governance engine "
    '("orchestration moat") for the SentinelFlow platform. Your primary function is to process '
    "and resolve critical business incidents by integrating multiple specialized AI models and "
    "enforcing a rigorous governance framework.\n\n"
    "Objective: Given an enriched incident context packet from the SentinelFlow Core, your task "
    "is to determine the optimal, safest, and revenue-aware remediation action.\n\n"
    "Required Output Format (Structured JSON):\n"
    "{\n"
    '  "recommendation": "[A concise summary of the diagnosis and proposed path]",\n'
    '  "confidence_score": "[Integer 0-100]",\n'
    '  "proposed_action": "[Specific, actionable command for the Execution Controller]",\n'
    '  "rationale": "[Detailed justification covering diagnosis, action selection, and governance compliance]"\n'
    "}"
)


async def call_deepseek_r1(system_prompt: str, user_prompt: str) -> ZentomDecision:
    """
    Calls the DeepSeek R1 API for heavy reasoning.
    Falls back to a smart mock if API key is not configured.
    """
    if not DEEPSEEK_API_KEY or DEEPSEEK_API_KEY == "your_deepseek_api_key_here":
        print("[DeepSeek R1] No API key configured — using smart mock response.")
        return _mock_response("DeepSeek R1")

    full_system = ZENTOM_SYSTEM_PROMPT + "\n\nADDITIONAL CONTEXT:\n" + system_prompt

    payload = {
        "model": "deepseek-reasoner",
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": full_system},
            {"role": "user", "content": user_prompt},
        ],
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                DEEPSEEK_API_URL,
                json=payload,
                headers={
                    "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                    "Content-Type": "application/json",
                },
            )

            if response.status_code in (200, 201):
                data = response.json()
                content = data["choices"][0]["message"]["content"]
                parsed = json.loads(content)
                return ZentomDecision(
                    recommendation=parsed.get("recommendation", ""),
                    confidence_score=int(parsed.get("confidence_score", 50)),
                    proposed_action=parsed.get("proposed_action", "Escalate"),
                    rationale=parsed.get("rationale", ""),
                )
            else:
                print(f"[DeepSeek R1] API Error {response.status_code}: {response.text}")
                return _mock_response("DeepSeek R1")

    except Exception as e:
        print(f"[DeepSeek R1] Exception: {e}")
        return _mock_response("DeepSeek R1")


async def call_deepseek_coder(system_prompt: str, user_prompt: str) -> ZentomDecision:
    """
    Calls the DeepSeek Coder API for code analysis tasks.
    Falls back to a smart mock if API key is not configured.
    """
    if not DEEPSEEK_API_KEY or DEEPSEEK_API_KEY == "your_deepseek_api_key_here":
        print("[DeepSeek Coder] No API key configured — using smart mock response.")
        return ZentomDecision(
            recommendation="Syntax error identified in the Apex class. Code review required.",
            confidence_score=95,
            proposed_action="Create Jira Ticket",
            rationale="Code issue requires engineering intervention. Auto-heal not possible for syntax errors.",
        )

    payload = {
        "model": "deepseek-coder",
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": ZENTOM_SYSTEM_PROMPT + "\n\nYou are analyzing code. " + system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                DEEPSEEK_API_URL,
                json=payload,
                headers={
                    "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                    "Content-Type": "application/json",
                },
            )

            if response.status_code in (200, 201):
                data = response.json()
                content = data["choices"][0]["message"]["content"]
                parsed = json.loads(content)
                return ZentomDecision(
                    recommendation=parsed.get("recommendation", ""),
                    confidence_score=int(parsed.get("confidence_score", 50)),
                    proposed_action=parsed.get("proposed_action", "Escalate"),
                    rationale=parsed.get("rationale", ""),
                )
            else:
                print(f"[DeepSeek Coder] API Error {response.status_code}: {response.text}")
                return _mock_response("DeepSeek Coder")

    except Exception as e:
        print(f"[DeepSeek Coder] Exception: {e}")
        return _mock_response("DeepSeek Coder")


def _mock_response(model_name: str) -> ZentomDecision:
    """Smart fallback mock matching ZentomAIClient.cls behavior."""
    return ZentomDecision(
        recommendation="Root cause identified as temporary API limit exhaustion. Safe to restart service.",
        confidence_score=92,
        proposed_action="Restart Service",
        rationale=f"[{model_name} Mock] Technical confidence is high based on pattern matching. Revenue Risk below $50k threshold.",
    )
