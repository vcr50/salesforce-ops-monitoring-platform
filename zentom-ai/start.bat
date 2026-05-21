@echo off
echo ========================================================
echo   ZENTOM AI - STARTING FULL PRODUCTION STACK
echo ========================================================

echo.
echo [1/5] Starting PostgreSQL and Redis via Docker Compose...
docker compose up -d

echo.
echo [2/5] Starting Localtunnel (Public URL: https://zentom-ai-backend-2026.loca.lt)...
start cmd /k "npx -y localtunnel --port 8000 --subdomain zentom-ai-backend-2026"

echo.
echo [3/5] Starting Celery Worker (Task Queue)...
start cmd /k ".\venv\Scripts\celery -A app.core.celery_app worker --loglevel=info --pool=solo"

echo.
echo [4/5] Starting FastAPI Server...
start cmd /k ".\venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"

echo.
echo [5/5] Opening Mission Control Dashboard...
start dashboard.html

echo.
echo ========================================================
echo   ALL SERVICES STARTED!
echo   - FastAPI: http://localhost:8000
echo   - Localtunnel: https://zentom-ai-backend-2026.loca.lt
echo   - Celery: Running in background window
echo   - Dashboard: Opened in your default browser
echo ========================================================
echo You can now run ".\venv\Scripts\python test_client.py" to send mock incidents!
pause
