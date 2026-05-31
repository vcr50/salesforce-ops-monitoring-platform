import os
from dotenv import load_dotenv

load_dotenv()

# Database
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://zentom_user:zentom_password@localhost:5432/zentom_db")

# AI API Keys
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
DEEPSEEK_API_URL = os.getenv("DEEPSEEK_API_URL", "https://api.deepseek.com/v1/chat/completions")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

# Ollama
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")

# Embedding Model
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")

# Webhook (Shared Secret for Salesforce callback authentication)
WEBHOOK_SECRET = os.getenv("ZENTOM_WEBHOOK_SECRET", "zentom-sf-shared-secret-v1")

# Celery / Redis
CELERY_BROKER_URL = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
