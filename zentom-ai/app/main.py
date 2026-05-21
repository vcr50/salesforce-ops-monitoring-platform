from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import api_router
from app.api.ws_routes import ws_router
from app.models.database import init_db
from app.core.security import APIKeyAuthMiddleware
from app.core.observability import deep_health_check, configure_logging
import uvicorn
import os

app = FastAPI(
    title="Zentom AI Backend",
    description="Standalone reasoning and orchestration backend for SentinelFlow. "
                "Implements the 8-engine Zentom Orchestration Moat with RAG memory, "
                "multi-model routing, and governed autonomous actions.",
    version="2.1.0"
)

# ─── Security Middleware (applied first, runs on every request) ──
app.add_middleware(APIKeyAuthMiddleware)

# ─── CORS (restricted in production) ────────────────────────────
ALLOWED_ORIGINS = os.getenv("ZENTOM_CORS_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")
app.include_router(ws_router, prefix="/api/v1")

@app.on_event("startup")
def on_startup():
    """Initialize database, logging, and observability on server startup."""
    configure_logging()
    init_db()

@app.get("/health")
async def health_check():
    """Basic liveness probe — always returns quickly."""
    return {"status": "ok", "service": "Zentom AI", "version": "2.1.0"}

@app.get("/health/deep")
async def deep_health():
    """
    Deep readiness probe — checks all subsystems.
    Returns DEGRADED if any subsystem is down.
    Not auth-gated so load balancers can probe it.
    """
    return deep_health_check()

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
