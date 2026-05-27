from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
import json
import uuid

from app.engines import chat_memory
from app.services import voice
from app.services import groq
from app.core.security import get_api_key_info, has_role

ws_router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, incident_id: str):
        await websocket.accept()
        self.active_connections[incident_id] = websocket

    def disconnect(self, incident_id: str):
        if incident_id in self.active_connections:
            del self.active_connections[incident_id]

    async def send_message(self, message: dict, incident_id: str):
        if incident_id in self.active_connections:
            await self.active_connections[incident_id].send_json(message)

manager = ConnectionManager()

@ws_router.websocket("/chat/{incident_id}")
async def websocket_endpoint(websocket: WebSocket, incident_id: str):
    api_key = websocket.query_params.get("api_key") or websocket.headers.get("X-API-Key")
    key_info = get_api_key_info(api_key)
    if not key_info or not has_role(key_info["role"], "OPERATOR"):
        await websocket.close(code=1008, reason="Unauthorized")
        return

    await manager.connect(websocket, incident_id)
    
    # Send a welcome message
    welcome_text = f"Zentom AI is connected to incident {incident_id}. You can chat with me or send voice clips."
    welcome_audio = voice.generate_speech(welcome_text)
    
    await manager.send_message({
        "type": "agent", 
        "text": welcome_text,
        "audio": welcome_audio
    }, incident_id)
    
    try:
        while True:
            # Wait for any message from the client
            data = await websocket.receive_text()
            payload = json.loads(data)
            
            user_text = ""
            
            if payload.get("type") == "voice":
                # Convert audio to text
                base64_audio = payload.get("audio")
                user_text = voice.transcribe_audio(base64_audio)
                
                # Echo the transcription back so the user knows what was heard
                await manager.send_message({
                    "type": "system",
                    "text": f"Transcribed: '{user_text}'"
                }, incident_id)
                
            elif payload.get("type") == "text":
                user_text = payload.get("text")
                
            if not user_text:
                continue
                
            # Add user message to conversational memory
            chat_memory.add_message(incident_id, "user", user_text)
            
            # Check if user is asking to take an action (this bridges Live Chat -> Orchestration)
            if "execute" in user_text.lower() or "fix" in user_text.lower():
                await manager.send_message({
                    "type": "agent",
                    "text": "Initiating execution through the Orchestration Engine... one moment."
                }, incident_id)
                # Here, we would trigger the full 8-engine orchestrator. For the PoC, we just respond textually.
                # If we imported `_run_orchestration_pipeline` we could execute it.
            
            # Formulate the prompt using conversation history
            history = chat_memory.get_formatted_history(incident_id)
            system_prompt = (
                "You are Zentom AI, the live orchestration assistant for Salesforce SentinelFlow. "
                "Chat with the user naturally, asking clarifying questions if needed. Keep answers concise. "
                f"\n{history}"
            )
            
            # Call Groq Llama 3.3 70B for real-time chat
            try:
                response = await groq.call_llama_r1(system_prompt=system_prompt, user_prompt=user_text)
                ai_text = response.recommendation
            except Exception:
                ai_text = f"I understand you are experiencing an issue regarding '{user_text}'. Can you provide more details so I can diagnose it?"
            
            # Add AI response to memory
            chat_memory.add_message(incident_id, "agent", ai_text)
            
            # Generate TTS audio
            ai_audio = voice.generate_speech(ai_text)
            
            # Send back to client
            await manager.send_message({
                "type": "agent",
                "text": ai_text,
                "audio": ai_audio
            }, incident_id)
            
    except WebSocketDisconnect:
        manager.disconnect(incident_id)
