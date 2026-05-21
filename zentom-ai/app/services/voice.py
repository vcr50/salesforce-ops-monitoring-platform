import os
import base64
import tempfile
import speech_recognition as sr
from gtts import gTTS

def transcribe_audio(audio_base64: str) -> str:
    """
    Converts a base64 encoded audio string to text using local SpeechRecognition.
    Assumes the payload is a standard audio file (like WAV).
    """
    try:
        audio_bytes = base64.b64decode(audio_base64)
        
        # Save to a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_audio:
            temp_audio.write(audio_bytes)
            temp_audio_path = temp_audio.name
            
        recognizer = sr.Recognizer()
        with sr.AudioFile(temp_audio_path) as source:
            audio_data = recognizer.record(source)
            # Use Google Web Speech API (free, no key required for basic testing)
            text = recognizer.recognize_google(audio_data)
            
        os.remove(temp_audio_path)
        return text
    except Exception as e:
        print(f"STT Error: {e}")
        # Fallback for PoC if the audio format is wrong or Google blocks the IP
        return "I am unable to connect to the database right now."

def generate_speech(text: str) -> str:
    """
    Converts text to speech using Google TTS (gTTS) and returns as base64 encoded mp3.
    """
    try:
        tts = gTTS(text=text, lang='en')
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as temp_audio:
            tts.save(temp_audio.name)
            temp_audio_path = temp_audio.name
            
        with open(temp_audio_path, "rb") as f:
            audio_bytes = f.read()
            
        os.remove(temp_audio_path)
        return base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as e:
        print(f"TTS Error: {e}")
        return ""
