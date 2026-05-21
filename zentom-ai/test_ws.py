import asyncio
import websockets
import json

async def test_websocket():
    uri = "ws://localhost:8000/api/v1/chat/TEST-INC-001"
    
    print(f"Connecting to {uri}...")
    try:
        async with websockets.connect(uri) as websocket:
            # 1. Wait for welcome message
            response = await websocket.recv()
            data = json.loads(response)
            print("\n[AI WELCOME]:", data['text'])
            print("Audio payload received:", "Yes" if 'audio' in data and data['audio'] else "No")
            
            # 2. Send a text message
            print("\nSending: 'Hello, I have a problem with my database.'")
            await websocket.send(json.dumps({"type": "text", "text": "Hello, I have a problem with my database."}))
            
            # 3. Wait for AI response
            response = await websocket.recv()
            data = json.loads(response)
            print("\n[AI RESPONSE]:", data['text'])
            print("Audio payload received:", "Yes" if 'audio' in data and data['audio'] else "No")
            
            # 4. Send a mock voice message
            print("\nSending mock Voice Base64 payload...")
            await websocket.send(json.dumps({
                "type": "voice", 
                "audio": "UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA="
            }))
            
            # 5. Wait for STT System Echo
            response = await websocket.recv()
            data = json.loads(response)
            print("\n[SYSTEM STT ECHO]:", data['text'])
            
            # 6. Wait for AI Voice Response
            response = await websocket.recv()
            data = json.loads(response)
            print("\n[AI RESPONSE]:", data['text'])
            print("Audio payload received:", "Yes" if 'audio' in data and data['audio'] else "No")
            
            print("\n[SUCCESS] WebSocket Chat Test Completed Successfully!")
            
    except Exception as e:
        print(f"\n[ERROR] WebSocket Test Failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket())
