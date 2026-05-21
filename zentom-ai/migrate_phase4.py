from sqlalchemy import text
from app.models.database import engine

MIGRATIONS = [
    "ALTER TABLE incident_memory ADD COLUMN IF NOT EXISTS org_id VARCHAR DEFAULT 'default'",
    "ALTER TABLE incident_memory ADD COLUMN IF NOT EXISTS shared BOOLEAN DEFAULT FALSE",
    "ALTER TABLE replay_log ADD COLUMN IF NOT EXISTS org_id VARCHAR DEFAULT 'default'",
    "ALTER TABLE evaluation_log ADD COLUMN IF NOT EXISTS org_id VARCHAR DEFAULT 'default'",
    "ALTER TABLE recovery_workflow ADD COLUMN IF NOT EXISTS org_id VARCHAR DEFAULT 'default'",
    "ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS org_id VARCHAR DEFAULT 'default'",
]

with engine.connect() as conn:
    for sql in MIGRATIONS:
        print(f"Running: {sql[:70]}...")
        conn.execute(text(sql))
    conn.commit()

print("MIGRATION COMPLETE")
