from sentence_transformers import SentenceTransformer
from app.models.database import SessionLocal, IncidentMemory
from app.core.config import EMBEDDING_MODEL

# Lazy-loaded global model instance
_model = None

def _get_model():
    global _model
    if _model is None:
        print(f"Loading embedding model: {EMBEDDING_MODEL}...")
        _model = SentenceTransformer(EMBEDDING_MODEL)
        print("Embedding model loaded.")
    return _model

def generate_embedding(text: str) -> list:
    """Generate a vector embedding from text using SentenceTransformers."""
    model = _get_model()
    embedding = model.encode(text)
    return embedding.tolist()

def index_incident(
    incident_id: str,
    error_signature: str,
    resolution: str,
    confidence_score: float = 0.0,
    was_successful: bool = True,
    org_id: str = "default",
):
    """
    Embed and store a resolved incident into PostgreSQL pgvector table.
    """
    embedding = generate_embedding(f"{error_signature} {resolution}")
    
    db = SessionLocal()
    try:
        new_memory = IncidentMemory(
            org_id=org_id,
            incident_id=incident_id,
            error_signature=error_signature,
            resolution=resolution,
            confidence_score=confidence_score,
            was_successful=was_successful,
            embedding=embedding
        )
        db.add(new_memory)
        db.commit()
        print(f"Memory indexed: {incident_id} | {error_signature[:50]}...")
        return {"status": "indexed", "incident_id": incident_id}
    except Exception as e:
        db.rollback()
        print(f"Error indexing memory: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        db.close()

def retrieve_memory(error_signature: str, top_k: int = 3, org_id: str = "default") -> dict:
    """
    Search for similar past incidents using pgvector's cosine distance operator (<=>).
    """
    query_embedding = generate_embedding(error_signature)
    
    db = SessionLocal()
    try:
        # pgvector uses cosine distance (<=>). Cosine similarity = 1 - cosine distance
        results = (
            db.query(
                IncidentMemory, 
                IncidentMemory.embedding.cosine_distance(query_embedding).label("distance")
            )
            .filter(IncidentMemory.was_successful == True)
            .filter(IncidentMemory.org_id == org_id)
            .order_by(IncidentMemory.embedding.cosine_distance(query_embedding))
            .limit(top_k)
            .all()
        )
        
        if not results:
            return {
                "found": False,
                "resolution": "No historical memory found for this error signature.",
                "similarity": 0.0,
                "confidence": 0.0
            }
            
        best_match, best_distance = results[0]
        best_similarity = 1 - best_distance
        
        # Format the top matches
        scored = []
        for match, distance in results:
            scored.append({
                "incident_id": match.incident_id,
                "error_signature": match.error_signature,
                "resolution": match.resolution,
                "confidence": match.confidence_score,
                "similarity": 1 - distance
            })
            
        if best_similarity >= 0.5:
            return {
                "found": True,
                "resolution": best_match.resolution,
                "similarity": round(best_similarity, 4),
                "confidence": best_match.confidence_score,
                "matched_incident": best_match.incident_id,
                "top_matches": scored
            }
        else:
            return {
                "found": False,
                "resolution": "No sufficiently similar historical incident found.",
                "similarity": round(best_similarity, 4),
                "confidence": 0.0
            }
    finally:
        db.close()
