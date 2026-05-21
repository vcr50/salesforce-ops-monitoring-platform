from sqlalchemy import text
from app.models.database import engine

ORG_ID = "org_sentinelflow_prod"

UPDATES = [
    f"UPDATE replay_log SET org_id = '{ORG_ID}' WHERE org_id = 'default'",
    f"UPDATE evaluation_log SET org_id = '{ORG_ID}' WHERE org_id = 'default'",
    f"UPDATE recovery_workflow SET org_id = '{ORG_ID}' WHERE org_id = 'default'",
    f"UPDATE incident_memory SET org_id = '{ORG_ID}' WHERE org_id = 'default'",
    f"UPDATE audit_log SET org_id = '{ORG_ID}' WHERE org_id = 'default'",
]

with engine.connect() as conn:
    for sql in UPDATES:
        result = conn.execute(text(sql))
        print(f"  Updated {result.rowcount} rows: {sql[:60]}...")
    conn.commit()

print(f"\nAll data migrated to {ORG_ID}")
