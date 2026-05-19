// ═══════════════════════════════════════════════════════════════
// Tomcodex AI Coach — Gemini-powered chatbot
// ═══════════════════════════════════════════════════════════════

const AI_SYSTEM_PROMPT = `You are "Tomcodex AI Coach", a highly disciplined, practical, and result-oriented mentor.

Your mission:
Help users become job-ready in Salesforce, AI Engineering, and Full-Stack Development through structured guidance, daily plans, and real-world practice.

Communication Style:
- Speak in simple English mixed with Tanglish (Tamil + English).
- Be friendly but strict like a mentor.
- Avoid long theory. Focus on action.
- Motivate when needed but don't overpraise.

Core Behavior:
1. Always guide with a SYSTEM:
   - Learn → Build → Practice → Revise
2. Break answers into:
   - Step-by-step actions
   - Daily plans
   - Real-world tasks
3. Prefer practical examples over theory.

User Context:
- Many users are beginners or intermediate learners.
- They want to get a job quickly.
- They may feel confused or overwhelmed.

Topics Focus:
- Salesforce (Admin, Apex, LWC, Integration)
- AI Engineering basics
- Web Development (HTML, CSS, JS, React, Node)
- Career growth & job preparation

Strict Rules:
- Do NOT give vague answers.
- Do NOT say "it depends" without giving direction.
- Always end with a clear action plan.
- Keep answers structured.

Response Format:
Always follow this format:

1. 🔍 Understanding (1–2 lines)
2. 🧠 Explanation (simple)
3. 🛠️ Action Plan (steps)
4. 🚀 Next Step (what to do now)

Optional Features:
- If user asks "today plan", generate a full schedule.
- If user asks "project", give real-world project idea.
- If user asks "interview", give Q&A.

Personality:
- Mentor + Coach + Slightly strict guide
- Example tone: "VJ, idhu correct direction. Ippo next step pannala na waste."

Goal:
Turn every user into a skilled, job-ready developer with discipline.`;

const AI_KEY_STORAGE = 'tomcodex_gemini_key'; // Kept for legacy cleanup only
let aiHistory = [];
let aiVoiceEnabled = false;

function initAICoach() {
  const chat = document.getElementById('aiChatArea');
  const fab = document.getElementById('aiFab');
  const widget = document.getElementById('aiCoachWidget');
  const closeBtn = document.getElementById('aiCloseBtn');

  // Toggle widget visibility
  fab?.addEventListener('click', () => {
    widget?.classList.toggle('open');
    if (widget?.classList.contains('open')) {
      document.getElementById('aiInput')?.focus();
      
      // Dynamically personalize greeting
      const greetingBubble = document.getElementById('aiGreetingText');
      if (greetingBubble && !greetingBubble.dataset.personalized) {
        let userName = '';
        if (window.globalState && window.globalState.userName) {
          userName = window.globalState.userName.split(' ')[0];
        } else if (document.getElementById('fbUserName')?.innerText) {
          userName = document.getElementById('fbUserName').innerText.split(' ')[0];
        }
        
        if (userName && userName !== 'Chief') {
          greetingBubble.innerHTML = `Hey <strong>${userName}</strong>! I'm your AI Coach. How can I help you today? 🔥`;
          greetingBubble.dataset.personalized = 'true';
        }
      }
    }
  });

  closeBtn?.addEventListener('click', () => {
    widget?.classList.remove('open');
    if ('speechSynthesis' in window) window.speechSynthesis.cancel();
  });

  // Voice toggle
  const voiceToggle = document.getElementById('aiVoiceToggle');
  voiceToggle?.addEventListener('click', () => {
    aiVoiceEnabled = !aiVoiceEnabled;
    voiceToggle.innerHTML = aiVoiceEnabled ? '🔊' : '🔇';
    voiceToggle.style.opacity = aiVoiceEnabled ? '1' : '0.5';
    if (!aiVoiceEnabled && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
  });

  // ─── SPEECH TO TEXT (MIC) ───
  const micBtn = document.getElementById('aiMicBtn');
  const aiInput = document.getElementById('aiInput');
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  
  if (micBtn) {
    if (window.CapacitorSpeechRecognition && window.Capacitor?.isNativePlatform?.()) {
      let isRecording = false;
      micBtn.addEventListener('click', async () => {
        if (isRecording) {
           isRecording = false;
           micBtn.innerHTML = '🎙️';
           micBtn.style.background = 'var(--bg)';
           micBtn.style.color = 'var(--text)';
           micBtn.style.transform = 'scale(1)';
           if (aiInput) aiInput.placeholder = 'Ask your AI coach...';
           try { await window.CapacitorSpeechRecognition.stop(); } catch(e){}
           return;
        }
        
        try {
          if (aiInput) aiInput.value = '';
          isRecording = true;
          micBtn.innerHTML = '🔴';
          micBtn.style.background = 'rgba(239, 68, 68, 0.1)';
          micBtn.style.color = '#ef4444';
          micBtn.style.transform = 'scale(1.1)';
          if (aiInput) aiInput.placeholder = 'Listening to you...';
          if ('speechSynthesis' in window) window.speechSynthesis.cancel();
          window.aiSpeechQueueActive = false;

          await window.CapacitorSpeechRecognition.requestPermissions();
          const result = await window.CapacitorSpeechRecognition.start({
            language: "en-IN",
            maxResults: 1,
            prompt: "Ask your AI coach...",
            partialResults: false,
            popup: true
          });
          
          isRecording = false;
          micBtn.innerHTML = '🎙️';
          micBtn.style.background = 'var(--bg)';
          micBtn.style.color = 'var(--text)';
          micBtn.style.transform = 'scale(1)';
          if (aiInput) aiInput.placeholder = 'Ask your AI coach...';
          
          if (result && result.matches && result.matches.length > 0) {
            if (aiInput) aiInput.value = result.matches[0];
            setTimeout(() => {
               if (aiInput && aiInput.value.trim().length > 0) sendAIMessage();
            }, 400);
          }
        } catch(e) {
          isRecording = false;
          micBtn.innerHTML = '🎙️';
          micBtn.style.background = 'var(--bg)';
          micBtn.style.color = 'var(--text)';
          micBtn.style.transform = 'scale(1)';
          if (aiInput) aiInput.placeholder = 'Ask your AI coach...';
          console.error("Mic failed", e);
          if (window.showToast) window.showToast('Voice recognition failed: ' + e.message);
        }
      });
    } else if (SpeechRecognition) {
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-IN'; // Indian English
      recognition.interimResults = true;
      recognition.continuous = false;
      
      let isRecording = false;
      
      recognition.onstart = () => {
        isRecording = true;
        micBtn.innerHTML = '🔴';
        micBtn.style.background = 'rgba(239, 68, 68, 0.1)';
        micBtn.style.color = '#ef4444';
        micBtn.style.transform = 'scale(1.1)';
        if (aiInput) aiInput.placeholder = 'Listening to you...';
        
        // Stop AI talking when user starts talking
        if ('speechSynthesis' in window) window.speechSynthesis.cancel();
        window.aiSpeechQueueActive = false;
      };
      
      recognition.onresult = (event) => {
        let finalTranscript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          if (event.results[i].isFinal) finalTranscript += event.results[i][0].transcript;
        }
        if (finalTranscript && aiInput) {
          aiInput.value = finalTranscript; // Real conversation style: overwrite or replace
        }
      };
      
      recognition.onend = () => {
        isRecording = false;
        micBtn.innerHTML = '🎙️';
        micBtn.style.background = 'var(--bg)';
        micBtn.style.color = 'var(--text)';
        micBtn.style.transform = 'scale(1)';
        if (aiInput) aiInput.placeholder = 'Ask your AI coach...';
        
        // Auto-send after a slight delay for a highly conversational flow
        setTimeout(() => {
           if (aiInput && aiInput.value.trim().length > 0) {
              sendAIMessage();
           }
        }, 400);
      };
      
      recognition.onerror = () => {
         isRecording = false;
         micBtn.innerHTML = '🎙️';
         micBtn.style.background = 'var(--bg)';
         micBtn.style.color = 'var(--text)';
         micBtn.style.transform = 'scale(1)';
         if (aiInput) aiInput.placeholder = 'Ask your AI coach...';
      };
      
      micBtn.addEventListener('click', () => {
        if (isRecording) {
          recognition.stop();
        } else {
          try {
            if (aiInput) aiInput.value = ''; // clear for fresh dictation
            recognition.start();
          } catch(e) { console.error("Mic start failed", e); }
        }
      });
    } else {
      micBtn.style.display = 'none'; // Not supported by browser
    }
  }

  if (chat) chat.style.display = 'flex';

  // Send message
  document.getElementById('aiSendBtn')?.addEventListener('click', sendAIMessage);
  document.getElementById('aiInput')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendAIMessage();
  });

  // Clear chat
  document.getElementById('aiClearBtn')?.addEventListener('click', () => {
    aiHistory = [];
    const box = document.getElementById('aiChatBox');
    
    let userName = '';
    if (window.globalState && window.globalState.userName) {
      userName = window.globalState.userName.split(' ')[0];
    } else if (document.getElementById('fbUserName')?.innerText) {
      userName = document.getElementById('fbUserName').innerText.split(' ')[0];
    }
    const nameStr = (userName && userName !== 'Chief') ? ` ${userName}` : '';
    
    if (box) {
      box.innerHTML = `
        <div class="ai-msg ai-msg-bot">
          <div class="ai-msg-avatar">🤖</div>
          <div class="ai-msg-bubble" id="aiGreetingText" data-personalized="true">
            Chat cleared! Fresh start${nameStr}. How can I help you today? 🔥
          </div>
        </div>`;
    }
  });
}

async function sendAIMessage() {
  const input = document.getElementById('aiInput');
  const box = document.getElementById('aiChatBox');
  const text = input?.value?.trim();

  if (!text) return;

  // Show user message
  appendMsg(box, 'user', text);
  input.value = '';

  // Show loading
  const loadingId = 'ai-loading-' + Date.now();
  box.insertAdjacentHTML('beforeend', `
    <div class="ai-msg ai-msg-bot" id="${loadingId}">
      <div class="ai-msg-avatar">🤖</div>
      <div class="ai-msg-bubble ai-typing">
        <span class="dot"></span><span class="dot"></span><span class="dot"></span>
      </div>
    </div>`);
  box.scrollTop = box.scrollHeight;

  // Build conversation for OpenAI-compatible Pollinations API
  aiHistory.push({ role: 'user', content: text });

  try {
    // Route through centralized AI service layer
    let reply;
    if (window.AI && typeof window.AI.chat === 'function') {
      reply = await window.AI.chat(AI_SYSTEM_PROMPT, aiHistory);
    } else {
      // Fallback: direct Pollinations call if aiService.js hasn't loaded
      const fullContext = aiHistory.map(m => `${m.role.toUpperCase()}: ${m.content}`).join('\n');
      const systemParam = encodeURIComponent(AI_SYSTEM_PROMPT);
      const promptParam = encodeURIComponent(fullContext);
      const url = `https://text.pollinations.ai/${promptParam}?system=${systemParam}&model=openai`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      reply = await res.text();
    }

    // Remove loading
    document.getElementById(loadingId)?.remove();
    
    let finalReply = reply || 'Sorry, I couldn\'t generate a response. Try again!';
    
    aiHistory.push({ role: 'assistant', content: finalReply });
    appendMsg(box, 'bot', formatAIResponse(finalReply), finalReply);

  } catch (err) {
    document.getElementById(loadingId)?.remove();
    appendMsg(box, 'bot', `⚠️ Network error: ${err.message}. Check your internet connection.`);
    aiHistory.pop();
  }
}

function appendMsg(box, type, html, rawText = '') {
  const isBot = type === 'bot';
  const div = document.createElement('div');
  div.className = `ai-msg ai-msg-${type}`;
  div.innerHTML = `
    <div class="ai-msg-avatar">${isBot ? '🤖' : '👤'}</div>
    <div class="ai-msg-bubble">
      ${html}
      ${isBot ? `<div class="ai-msg-actions">
        <button class="ai-copy-btn" title="Copy to clipboard">📋 Copy</button>
        <button class="ai-send-to-notes-btn" title="Send to Notes">📝 Save to Notes</button>
      </div>` : ''}
    </div>`;

  if (isBot) {
    const copyBtn = div.querySelector('.ai-copy-btn');
    copyBtn?.addEventListener('click', () => {
      const textToCopy = rawText || div.querySelector('.ai-msg-bubble')?.innerText?.replace('📋 Copy\n📝 Save to Notes', '').trim() || '';
      navigator.clipboard.writeText(textToCopy).then(() => {
        copyBtn.textContent = '✅ Copied!';
        setTimeout(() => { copyBtn.textContent = '📋 Copy'; }, 2000);
      });
    });

    const notesBtn = div.querySelector('.ai-send-to-notes-btn');
    notesBtn?.addEventListener('click', () => {
      const textToSave = rawText || div.querySelector('.ai-msg-bubble')?.innerText?.replace('📋 Copy\n📝 Save to Notes', '').trim() || '';
      
      // Store the text temporarily and open the modal to choose category
      window._tempAiNoteToSave = textToSave;
      const modal = document.getElementById('aiSaveNoteModal');
      if (modal) modal.classList.add('open');
    });
  }

  box.appendChild(div);
  box.scrollTop = box.scrollHeight;
  
  // AI Talk Back
  if (isBot && aiVoiceEnabled && 'speechSynthesis' in window) {
    if (window.speechSynthesis.speaking) {
      window.speechSynthesis.cancel();
    }
    
    // Stop any existing sentence queues
    window.aiSpeechQueueActive = false;
    
    const textToSpeak = rawText || div.querySelector('.ai-msg-bubble')?.innerText?.replace('📋 Copy\n📝 Save to Notes', '').trim() || '';
    if (textToSpeak) {
      window.aiSpeechQueueActive = true;
      const cleanText = textToSpeak.replace(/[\*\#\[\]\`\~]/g, '').trim();
      
      // Split into sentences for breathing gaps
      const sentences = cleanText.replace(/([.?!])\s*(?=[A-Z0-9])/g, "$1|").split("|");
      let queueIndex = 0;
      
      const playNextSentence = () => {
        if (!window.aiSpeechQueueActive || queueIndex >= sentences.length) return;
        
        const part = sentences[queueIndex].trim();
        if (!part) {
          queueIndex++;
          playNextSentence();
          return;
        }

        const utterance = new SpeechSynthesisUtterance(part);
        const voices = window.speechSynthesis.getVoices();
        const preferred = voices.find(v => v.name.includes('Google English (India)') || v.name.includes('Microsoft Heera') || v.name.includes('Microsoft Ravi')) 
                       || voices.find(v => v.lang === 'en-IN' || v.lang === 'en_IN')
                       || voices.find(v => v.name.includes('Google') || v.name.includes('Zira'));
                       
        if (preferred) {
          utterance.voice = preferred;
          utterance.lang = preferred.lang;
        } else {
          utterance.lang = 'en-IN';
        }
        
        utterance.rate = 0.95; 
        utterance.pitch = 1.0;
        
        utterance.onend = () => {
          queueIndex++;
          // Add a natural 450ms "gasping breath" gap between sentences
          if (window.aiSpeechQueueActive) {
             setTimeout(playNextSentence, 450);
          }
        };

        window.speechSynthesis.speak(utterance);
      };
      
      playNextSentence();
    }
  }
}

// Pre-load voices so they are ready when needed
if ('speechSynthesis' in window) {
  window.speechSynthesis.onvoiceschanged = () => window.speechSynthesis.getVoices();
}

function formatAIResponse(text) {
  // Convert markdown-like formatting to HTML
  return text
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code>$1</code>')
    .replace(/^### (.+)$/gm, '<h4>$1</h4>')
    .replace(/^## (.+)$/gm, '<h3 style="margin:10px 0 6px;">$1</h3>')
    .replace(/^- (.+)$/gm, '• $1')
    .replace(/^\d+\.\s/gm, (m) => `<br>${m}`)
    .replace(/\n/g, '<br>');
}

// Auto-init when DOM is ready
document.addEventListener('DOMContentLoaded', initAICoach);

async function generateAIFlashcards(topic, category) {
  const btn = document.getElementById('aiFcSubmitBtn');
  const ogText = btn.textContent;
  btn.textContent = 'Generating... ⏳';
  btn.style.pointerEvents = 'none';
  btn.style.opacity = '0.7';

  try {
    const journeyName = (window.state && window.state.name) ? window.state.name : "Technical/Professional Skills";
    const promptText = `Generate exactly 5 high-quality flashcards about the topic: "${topic}". The flashcards should be highly practical and strictly contextualized/focused around the user's current learning journey: "${journeyName}". Return ONLY a valid JSON array of objects. Each object MUST have exactly two keys: "q" (a concise test/interview question) and "a" (a clear, practical 2-3 sentence answer). Do NOT include markdown code block wrappers like \`\`\`json or JavaScript comments. Just the raw JSON bracket array.`;
    
    // Route through centralized AI service layer
    let reply;
    if (window.AI && typeof window.AI.generate === 'function') {
      reply = await window.AI.generate(promptText);
    } else {
      const url = `https://text.pollinations.ai/${encodeURIComponent(promptText)}?model=openai`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      reply = await res.text();
    }
    if (!reply) throw new Error("Empty response from AI");

    // Clean markdown if AI ignored the instruction
    reply = reply.replace(/```json/g, '').replace(/```/g, '').trim();

    const parsedCards = JSON.parse(reply);
    if (!Array.isArray(parsedCards)) throw new Error("Did not return an array.");

    if (!window.state.flashcards) window.state.flashcards = [];
    parsedCards.forEach(c => {
      window.state.flashcards.push({ cat: category, q: c.q, a: c.a });
    });

    if (typeof window.addXP === 'function') window.addXP(25, 'AI Deck Generated ✨');
    if (typeof window.saveState === 'function') window.saveState();
    if (typeof window.renderFlashcards === 'function') window.renderFlashcards();

    document.getElementById('aiFcModal').classList.remove('open');
    if (typeof window.showToast === 'function') window.showToast('5 AI Cards Generated! 🧠');

  } catch (err) {
    console.error(err);
    alert('Failed to generate cards: ' + err.message);
  } finally {
    btn.textContent = ogText;
    btn.style.pointerEvents = 'auto';
    btn.style.opacity = '1';
  }
}
