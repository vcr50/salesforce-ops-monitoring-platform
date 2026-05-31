from typing import List
from app.models.schemas import ContextPacket
from app.engines.memory import retrieve_memory

def assemble_context(
    incident_id: str,
    mock_arr: float = 150000.0,
    mock_error_signature: str = "",
    org_id: str = "default",
) -> ContextPacket:
    """
    Assembles full situational awareness before any AI reasoning.
    Now wired to the real Memory Engine for RAG retrieval.
    """
    similar_incidents: List[str] = []
    
    # 1. Memory Engine (Real RAG vector search)
    if mock_error_signature:
        memory_result = retrieve_memory(mock_error_signature, org_id=org_id)
        if memory_result["found"]:
            similar_incidents.append(
                f"Memory Match: {memory_result['resolution']} "
                f"(Similarity: {memory_result['similarity']}, "
                f"Confidence: {memory_result['confidence']})"
            )
        else:
            similar_incidents.append(memory_result["resolution"])
    
    # 2. Salesforce Business Context
    account_arr = mock_arr
    if account_arr >= 500000:
        account_tier = "Strategic"
    elif account_arr >= 100000:
        account_tier = "Enterprise"
    elif account_arr >= 25000:
        account_tier = "Growth"
    else:
        account_tier = "Standard"
        
    # 3. Knowledge Base
    runbook_url = "https://docs.sentinelflow.com/runbooks/auto-generated"
    
    # 4. Incident History
    incident_history = "5 incidents in the last 30 days."
    
    return ContextPacket(
        similarIncidents=similar_incidents,
        accountARR=account_arr,
        accountTier=account_tier,
        runbookUrl=runbook_url,
        incidentHistory=incident_history,
        errorSignature=mock_error_signature
    )
