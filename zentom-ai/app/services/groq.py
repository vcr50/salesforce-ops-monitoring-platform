import os
import json
import httpx
import logging
from pydantic import ValidationError
from app.models.schemas import ZentomDecision, ExecutionMode
from app.core.config import GROQ_API_KEY

logger = logging.getLogger("zentom.groq")

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
MAX_RETRIES = 3

ZENTOM_SYSTEM_PROMPT = (
    "You are the Zentom Orchestration System LLM, the central reasoning and governance engine "
    "(\"orchestration moat\") for the SentinelFlow platform. Your primary function is to process "
    "and resolve critical business incidents.\n\n"
    "CRITICAL: You MUST respond with ONLY valid JSON. No markdown, no explanation outside JSON.\n"
    "Required JSON schema:\n"
    "{\n"
    '  "recommendation": "[string — concise summary of the diagnosis and proposed path]",\n'
    '  "confidence_score": [integer 0-100],\n'
    '  "proposed_action": "[string — specific, actionable command for the Execution Controller]",\n'
    '  "rationale": "[string — detailed justification covering diagnosis, action selection, and governance compliance]"\n'
    "}\n\n"
    "Rules:\n"
    "- confidence_score MUST be an integer between 0 and 100.\n"
    "- proposed_action MUST be one of: Restart Service, Escalate, Retry Operation, Rollback, Update Record, Patch Configuration.\n"
    "- Do NOT wrap the JSON in markdown code fences.\n"
    "- Do NOT include any text outside the JSON object."
)


async def _call_groq_with_retries(
    model: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float = 0.3,
    model_label: str = "Groq"
) -> ZentomDecision:
    """
    Core Groq caller with strict Pydantic validation and self-healing retry loop.
    
    If the LLM returns malformed JSON or a payload that fails Pydantic validation,
    the error message is fed back to the LLM so it can self-correct. After MAX_RETRIES
    exhausted, we return a safe fallback that forces HUMAN_APPROVAL_REQUIRED.
    """
    if not GROQ_API_KEY:
        logger.warning(f"[{model_label}] No API key configured — returning mock response.")
        return _mock_response(model_label)

    full_system = ZENTOM_SYSTEM_PROMPT + "\n\nADDITIONAL CONTEXT:\n" + system_prompt

    messages = [
        {"role": "system", "content": full_system},
        {"role": "user", "content": user_prompt},
    ]

    last_error = None

    for attempt in range(1, MAX_RETRIES + 1):
        payload = {
            "model": model,
            "response_format": {"type": "json_object"},
            "messages": messages,
            "temperature": temperature,
            "max_tokens": 1024,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    GROQ_API_URL,
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {GROQ_API_KEY}",
                        "Content-Type": "application/json",
                    },
                )

                if response.status_code not in (200, 201):
                    last_error = f"API HTTP {response.status_code}: {response.text[:200]}"
                    logger.error(f"[{model_label}] Attempt {attempt}/{MAX_RETRIES} — {last_error}")
                    continue

                data = response.json()
                content = data["choices"][0]["message"]["content"]

                # ── STRICT PYDANTIC VALIDATION ──
                try:
                    parsed = json.loads(content)
                    decision = ZentomDecision(
                        recommendation=parsed["recommendation"],
                        confidence_score=int(parsed["confidence_score"]),
                        proposed_action=parsed["proposed_action"],
                        rationale=parsed["rationale"],
                    )
                    logger.info(
                        f"[{model_label}] Validated response on attempt {attempt} "
                        f"(confidence={decision.confidence_score})"
                    )
                    return decision

                except (json.JSONDecodeError, KeyError, TypeError, ValidationError) as parse_err:
                    last_error = str(parse_err)
                    logger.warning(
                        f"[{model_label}] Schema violation on attempt {attempt}/{MAX_RETRIES}: {last_error}"
                    )
                    # ── SELF-HEALING: feed the error back to the LLM ──
                    messages.append({"role": "assistant", "content": content})
                    messages.append({
                        "role": "user",
                        "content": (
                            f"Your previous response failed schema validation with error:\n"
                            f"{last_error}\n\n"
                            f"Please respond ONLY with valid JSON matching the exact schema "
                            f"specified in your system prompt. Do not include any text outside the JSON."
                        ),
                    })
                    continue

        except httpx.TimeoutException:
            last_error = "Request timed out after 30s"
            logger.error(f"[{model_label}] Attempt {attempt}/{MAX_RETRIES} — {last_error}")
            continue
        except Exception as e:
            last_error = str(e)
            logger.error(f"[{model_label}] Attempt {attempt}/{MAX_RETRIES} — Exception: {last_error}")
            continue

    # ── ALL RETRIES EXHAUSTED — SAFE FALLBACK ──
    logger.critical(
        f"[{model_label}] All {MAX_RETRIES} retries exhausted. Last error: {last_error}. "
        f"Returning safe fallback with HUMAN_APPROVAL_REQUIRED."
    )
    return _fallback_response(model_label, last_error)


async def call_llama_r1(system_prompt: str, user_prompt: str) -> ZentomDecision:
    """
    Calls Groq Llama 3.3 70B for high-risk, high-ARR incidents requiring deep reasoning.
    """
    return await _call_groq_with_retries(
        model="llama-3.3-70b-versatile",
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        temperature=0.3,
        model_label="Groq Llama 3.3 70B",
    )


async def call_llama_coder(system_prompt: str, user_prompt: str) -> ZentomDecision:
    """
    Calls Groq Llama 3.1 8B for code analysis tasks.
    """
    return await _call_groq_with_retries(
        model="llama-3.1-8b-instant",
        system_prompt="You are analyzing Apex/code issues. " + system_prompt,
        user_prompt=user_prompt,
        temperature=0.2,
        model_label="Groq Llama 3.1 8B Coder",
    )


def _mock_response(model_name: str) -> ZentomDecision:
    """Returns a deterministic mock when no API key is available (dev only)."""
    return ZentomDecision(
        recommendation="Root cause identified as temporary API limit exhaustion. Safe to restart service.",
        confidence_score=92,
        proposed_action="Restart Service",
        rationale=f"[{model_name} Mock] Technical confidence is high based on pattern matching.",
    )


def _fallback_response(model_name: str, error_detail: str) -> ZentomDecision:
    """
    Safe fallback when the LLM fails to produce a valid response after all retries.
    This decision is specifically designed to trigger HUMAN_APPROVAL_REQUIRED downstream
    in the Policy Engine because the confidence is set below the 80% threshold.
    """
    return ZentomDecision(
        recommendation=f"LLM output could not be validated after {MAX_RETRIES} attempts. Escalating to human operator.",
        confidence_score=0,
        proposed_action="Escalate",
        rationale=(
            f"[{model_name} FALLBACK] The AI model failed to produce a schema-compliant response. "
            f"Last error: {error_detail}. "
            f"This incident requires manual human review. No autonomous action will be taken."
        ),
    )
