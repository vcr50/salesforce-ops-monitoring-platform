"""
Zentom AI Security Layer
- API Key authentication via X-API-Key header
- Role-Based Access Control (RBAC): SYSTEM > ADMIN > OPERATOR
- Rate limiting per API key
"""
import os
import time
import logging
from collections import defaultdict
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger("zentom.security")

# ─── API Key Registry ────────────────────────────────────────────
# In production, this would be stored in a database or secrets manager.
# Format: { "api_key": {"name": "...", "role": "ADMIN|OPERATOR|SYSTEM"} }

API_KEYS = {}

def _load_api_keys():
    """Load API keys from environment variables."""
    global API_KEYS
    
    admin_key = os.getenv("ZENTOM_API_KEY_ADMIN", "ztm-admin-key-v1")
    operator_key = os.getenv("ZENTOM_API_KEY_OPERATOR", "ztm-operator-key-v1")
    system_key = os.getenv("ZENTOM_API_KEY_SYSTEM", "ztm-system-key-v1")
    default_org = os.getenv("ZENTOM_DEFAULT_ORG_ID", "org_sentinelflow_prod")
    
    API_KEYS = {
        admin_key: {"name": "Admin", "role": "ADMIN", "org_id": default_org},
        operator_key: {"name": "Operator", "role": "OPERATOR", "org_id": default_org},
        system_key: {"name": "System", "role": "SYSTEM", "org_id": default_org},
    }

_load_api_keys()

# ─── Role Hierarchy ──────────────────────────────────────────────
# SYSTEM > ADMIN > OPERATOR
ROLE_HIERARCHY = {"SYSTEM": 3, "ADMIN": 2, "OPERATOR": 1}

def has_role(user_role: str, required_role: str) -> bool:
    """Check if user_role meets or exceeds required_role."""
    return ROLE_HIERARCHY.get(user_role, 0) >= ROLE_HIERARCHY.get(required_role, 99)

def get_api_key_info(api_key: str | None) -> dict | None:
    """Return registered API key metadata, if the key is valid."""
    if not api_key:
        return None
    return API_KEYS.get(api_key)

# ─── Route-level RBAC ────────────────────────────────────────────
# Maps route path prefixes to minimum required roles.
ROUTE_PERMISSIONS = {
    "/api/v1/approvals/": "ADMIN",       # approve/reject require ADMIN
    "/api/v1/orchestrate": "SYSTEM",     # only machines orchestrate
    "/api/v1/evaluate": "SYSTEM",        # only machines send feedback
    "/api/v1/verify/": "ADMIN",          # verification requires ADMIN
    "/api/v1/memory/share": "ADMIN",     # sharing memory requires ADMIN
    "/api/v1/memory/search/cross-org": "OPERATOR",  # cross-org search for operators+
    "/api/v1/memory/": "SYSTEM",         # memory ops are machine-only
    "/api/v1/analytics/": "OPERATOR",    # anyone authenticated can read analytics
    "/api/v1/metrics": "OPERATOR",       # anyone authenticated can read metrics
    "/api/v1/audit/": "ADMIN",           # audit logs require ADMIN
    "/api/v1/chat/": "OPERATOR",         # chat is open to operators
}

def get_required_role(path: str) -> str:
    """Determine the minimum role required for a given path."""
    for prefix, role in ROUTE_PERMISSIONS.items():
        if path.startswith(prefix):
            return role
    return "OPERATOR"  # default: any authenticated user

# ─── Rate Limiting ───────────────────────────────────────────────
RATE_LIMIT_WINDOW = 60  # seconds
RATE_LIMIT_MAX = 120    # requests per window per key

_rate_store = defaultdict(list)

def _check_rate_limit(api_key: str) -> bool:
    """Simple sliding-window rate limiter."""
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    
    # Clean old entries
    _rate_store[api_key] = [t for t in _rate_store[api_key] if t > window_start]
    
    if len(_rate_store[api_key]) >= RATE_LIMIT_MAX:
        return False
    
    _rate_store[api_key].append(now)
    return True

# ─── Exempt Paths ────────────────────────────────────────────────
EXEMPT_PATHS = {"/health", "/docs", "/openapi.json", "/redoc"}

# ─── Auth Middleware ─────────────────────────────────────────────

class APIKeyAuthMiddleware(BaseHTTPMiddleware):
    """
    FastAPI middleware that validates the X-API-Key header on every request.
    Exempt paths (health, docs) are passed through without auth.
    WebSocket upgrade requests are also passed through (they use query params).
    """
    
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        
        # Exempt paths
        if path in EXEMPT_PATHS:
            return await call_next(request)
        
        # WebSocket connections pass through (auth handled at connection level)
        if request.headers.get("upgrade", "").lower() == "websocket":
            return await call_next(request)
        
        # Skip auth for non-API routes
        if not path.startswith("/api/"):
            return await call_next(request)
        
        # ── Extract API Key ──
        api_key = request.headers.get("X-API-Key")
        
        if not api_key:
            logger.warning(f"[Auth] Rejected: No API key for {request.method} {path}")
            return JSONResponse(
                status_code=401,
                content={"error": "Missing X-API-Key header"}
            )
        
        key_info = API_KEYS.get(api_key)
        if not key_info:
            logger.warning(f"[Auth] Rejected: Invalid API key for {request.method} {path}")
            return JSONResponse(
                status_code=403,
                content={"error": "Invalid API key"}
            )
        
        # ── Rate Limit ──
        if not _check_rate_limit(api_key):
            logger.warning(f"[Auth] Rate limited: {key_info['name']} on {path}")
            return JSONResponse(
                status_code=429,
                content={"error": "Rate limit exceeded. Try again later."}
            )
        
        # ── RBAC Check ──
        required_role = get_required_role(path)
        if not has_role(key_info["role"], required_role):
            logger.warning(
                f"[Auth] RBAC denied: {key_info['name']} ({key_info['role']}) "
                f"tried {path} (requires {required_role})"
            )
            return JSONResponse(
                status_code=403,
                content={"error": f"Insufficient permissions. Requires {required_role} role."}
            )
        
        # ── Attach identity to request state ──
        request.state.api_key_name = key_info["name"]
        request.state.api_key_role = key_info["role"]
        request.state.org_id = key_info.get("org_id", "default")
        
        response = await call_next(request)
        return response
