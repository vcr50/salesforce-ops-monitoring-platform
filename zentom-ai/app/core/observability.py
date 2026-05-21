"""
Zentom AI Observability Module
- Deep health probes for all subsystems
- Trace ID generation and propagation
- Structured logging configuration
"""
import os
import uuid
import time
import logging
from datetime import datetime

logger = logging.getLogger("zentom.observability")

# ─── Trace ID ────────────────────────────────────────────────────

def generate_trace_id() -> str:
    """Generate a short, human-readable trace ID."""
    return f"ztm-{uuid.uuid4().hex[:12]}"


# ─── Deep Health Probe ───────────────────────────────────────────

def probe_postgresql() -> dict:
    """Check PostgreSQL connectivity and table count."""
    start = time.time()
    try:
        from sqlalchemy import text
        from app.models.database import engine
        with engine.connect() as conn:
            result = conn.execute(text("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'"))
            table_count = result.scalar()
        latency = round((time.time() - start) * 1000, 1)
        return {"status": "UP", "latencyMs": latency, "tables": table_count}
    except Exception as e:
        return {"status": "DOWN", "error": str(e)[:120]}


def probe_redis() -> dict:
    """Check Redis connectivity."""
    start = time.time()
    try:
        import redis
        broker_url = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
        r = redis.from_url(broker_url, socket_timeout=3)
        r.ping()
        latency = round((time.time() - start) * 1000, 1)
        return {"status": "UP", "latencyMs": latency}
    except Exception as e:
        return {"status": "DOWN", "error": str(e)[:120]}


def probe_groq_api() -> dict:
    """Check Groq API key is configured (doesn't make a live call)."""
    api_key = os.getenv("GROQ_API_KEY", "")
    if api_key and len(api_key) > 10:
        return {"status": "UP", "keyConfigured": True, "keyPrefix": api_key[:8] + "..."}
    return {"status": "DEGRADED", "keyConfigured": False}


def probe_embedding_model() -> dict:
    """Check if the embedding model is loaded."""
    try:
        from app.engines.memory import _model
        if _model is not None:
            return {"status": "UP", "model": os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")}
        return {"status": "NOT_LOADED", "detail": "Model loads on first use"}
    except Exception as e:
        return {"status": "ERROR", "error": str(e)[:120]}


def deep_health_check() -> dict:
    """
    Comprehensive health check across all subsystems.
    Returns overall status: UP, DEGRADED, or DOWN.
    """
    probes = {
        "postgresql": probe_postgresql(),
        "redis": probe_redis(),
        "groqApi": probe_groq_api(),
        "embeddingModel": probe_embedding_model(),
    }

    # Determine overall status
    statuses = [p["status"] for p in probes.values()]
    if all(s == "UP" for s in statuses):
        overall = "UP"
    elif any(s == "DOWN" for s in statuses):
        overall = "DEGRADED"
    else:
        overall = "UP"

    return {
        "status": overall,
        "service": "Zentom AI",
        "version": "2.1.0",
        "timestamp": datetime.utcnow().isoformat(),
        "subsystems": probes,
    }


# ─── Structured Logging Setup ────────────────────────────────────

def configure_logging():
    """Configure structured JSON-style logging for production."""
    log_level = os.getenv("ZENTOM_LOG_LEVEL", "INFO").upper()

    # Create a formatter that includes trace context
    formatter = logging.Formatter(
        "[%(asctime)s] %(levelname)s %(name)s | %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S"
    )

    # Root handler
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)

    # Configure zentom loggers
    for logger_name in ["zentom", "zentom.security", "zentom.audit", "zentom.execution",
                        "zentom.verification", "zentom.predictive", "zentom.observability"]:
        lg = logging.getLogger(logger_name)
        lg.setLevel(getattr(logging, log_level, logging.INFO))
        lg.handlers = [handler]
        lg.propagate = False
