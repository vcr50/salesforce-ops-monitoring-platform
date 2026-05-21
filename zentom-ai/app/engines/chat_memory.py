from typing import List, Dict, Any

# In-memory store for chat histories mapped by incident_id.
# For production, this would be backed by Redis or PostgreSQL JSON columns.
CHAT_MEMORIES: Dict[str, List[Dict[str, str]]] = {}

def get_chat_history(incident_id: str) -> List[Dict[str, str]]:
    """Retrieve the chat history for a specific incident."""
    if incident_id not in CHAT_MEMORIES:
        CHAT_MEMORIES[incident_id] = []
    return CHAT_MEMORIES[incident_id]

def add_message(incident_id: str, role: str, content: str):
    """Add a message to the incident's chat history."""
    history = get_chat_history(incident_id)
    history.append({"role": role, "content": content})
    
def get_formatted_history(incident_id: str) -> str:
    """Format the history into a string block for the LLM prompt."""
    history = get_chat_history(incident_id)
    if not history:
        return "No prior conversation history."
        
    formatted = "--- Conversation History ---\n"
    for msg in history:
        formatted += f"{msg['role'].upper()}: {msg['content']}\n"
    formatted += "--------------------------\n"
    return formatted

def clear_memory(incident_id: str):
    """Clear the chat history for an incident."""
    if incident_id in CHAT_MEMORIES:
        del CHAT_MEMORIES[incident_id]
