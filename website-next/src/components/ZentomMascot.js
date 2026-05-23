'use client';
import React, { useState, useEffect } from 'react';
import { Bot, Send, X } from 'lucide-react';
import './ZentomMascot.css';

export default function ZentomMascot() {
  const [isEnabled, setIsEnabled] = useState(true);
  const [isChatOpen, setIsChatOpen] = useState(false);
  const [state, setState] = useState('idle'); // idle, angry, excited, thinking
  const [message, setMessage] = useState('');
  const [showMessage, setShowMessage] = useState(false);
  const [input, setInput] = useState('');
  const [chatMessages, setChatMessages] = useState([
    {
      role: 'bot',
      text: 'Hi, I am Zentom AI. Ask me about SentinelFlow, pricing, integrations, or self-healing.'
    }
  ]);
  
  const say = React.useCallback((text, duration = 3000) => {
    setMessage(text);
    setShowMessage(true);
    setTimeout(() => {
      setShowMessage(false);
    }, duration);
  }, []);

  useEffect(() => {
    const timeout = setTimeout(() => {
      const stored = localStorage.getItem('zentom_mascot_enabled');
      if (stored === 'false') {
        setIsEnabled(false);
      }
    }, 0);

    return () => clearTimeout(timeout);
  }, []);

  useEffect(() => {
    if (!isEnabled) return;

    const greetingTimeout = setTimeout(() => {
      say('Zentom AI Guardian online.', 4000);
    }, 0);

    // Polling the backend for logs to determine state
    const interval = setInterval(async () => {
      try {
        const res = await fetch('/api/zentom/logs');
        if (!res.ok) return;
        const data = await res.json();
        
        if (data.logs && data.logs.length > 0) {
          // Check if there are any critical / blocked actions recently
          const recent = data.logs.slice(0, 3);
          const hasBlocked = recent.some(l => l.status === 'BLOCKED' || l.status === 'FAILED');
          const hasHeal = recent.some(l => l.action.includes('Heal') || l.action.includes('Remediate'));
          
          // Only change state if it makes sense, and reset to idle eventually
          if (hasBlocked) {
            setState('angry');
            say('Blocked anomalous behavior!', 3000);
            setTimeout(() => setState('idle'), 5000);
          } else if (hasHeal) {
            setState('excited');
            say('System successfully healed!', 3000);
            setTimeout(() => setState('idle'), 5000);
          } else {
            // Randomly think sometimes
            if (Math.random() > 0.8) {
              setState('thinking');
              setTimeout(() => setState('idle'), 3000);
            }
          }
        }
      } catch (err) {
        console.error('Mascot Error:', err);
      }
    }, 10000);

    return () => {
      clearTimeout(greetingTimeout);
      clearInterval(interval);
    };
  }, [isEnabled, say]);

  const getBotReply = (question) => {
    const q = question.toLowerCase();

    if (q.includes('price') || q.includes('pricing') || q.includes('plan') || q.includes('cost')) {
      return 'SentinelFlow has Starter, Professional, and Enterprise plans. Jump to pricing to compare features and start a trial.';
    }

    if (q.includes('demo') || q.includes('trial')) {
      return 'You can book a demo or start a free trial from the page CTAs. I can also point you to the pricing section.';
    }

    if (q.includes('heal') || q.includes('incident') || q.includes('failure')) {
      return 'SentinelFlow detects Salesforce incidents, classifies root cause, recommends runbooks, and can auto-heal approved failures.';
    }

    if (q.includes('integration') || q.includes('salesforce') || q.includes('agent')) {
      return 'SentinelFlow is built for Salesforce operations with AgentExchange-ready automation, incident memory, dashboards, and reliability simulation.';
    }

    if (q.includes('about') || q.includes('tomcodex')) {
      return 'TomCodeX builds intelligent Salesforce reliability products. Use About Us in the footer to visit the TomCodeX about page.';
    }

    return 'I can help with SentinelFlow features, pricing, Salesforce setup, demo requests, and Zentom AI capabilities.';
  };

  const sendMessage = (text = input) => {
    const trimmed = text.trim();
    if (!trimmed) return;

    setChatMessages((messages) => [
      ...messages,
      { role: 'user', text: trimmed },
      { role: 'bot', text: getBotReply(trimmed) }
    ]);
    setInput('');
    setState('thinking');
    setTimeout(() => setState('idle'), 1200);
  };

  const handlePoke = () => {
    setIsChatOpen(true);
    if (state === 'idle') setState('excited');
    say('Zentom AI bot is ready. Ask me anything.', 3000);
    setTimeout(() => setState('idle'), 3000);
  };

  const handleDisable = (e) => {
    e.stopPropagation();
    setIsEnabled(false);
    localStorage.setItem('zentom_mascot_enabled', 'false');
  };

  if (!isEnabled) return null;

  const getImagePath = () => {
    switch (state) {
      case 'angry': return '/mascot/angry.png';
      case 'excited': return '/mascot/excited.png';
      case 'thinking': return '/mascot/thinking.png';
      default: return '/mascot/idle.png';
    }
  };

  return (
    <div className={`mascot-container mascot-${state}`}>
      {isChatOpen && (
        <section className="zentom-chat-panel" aria-label="Zentom AI bot">
          <div className="zentom-chat-header">
            <div>
              <span className="zentom-chat-kicker"><Bot size={14} /> Zentom AI</span>
              <strong>SentinelFlow assistant</strong>
            </div>
            <button className="zentom-chat-close" aria-label="Close Zentom chat" onClick={() => setIsChatOpen(false)}>
              <X size={16} />
            </button>
          </div>

          <div className="zentom-chat-messages">
            {chatMessages.map((chat, index) => (
              <div key={`${chat.role}-${index}`} className={`zentom-chat-message ${chat.role}`}>
                {chat.text}
              </div>
            ))}
          </div>

          <div className="zentom-chat-prompts" aria-label="Suggested questions">
            {['Pricing', 'Auto-heal', 'Book demo'].map((prompt) => (
              <button key={prompt} type="button" onClick={() => sendMessage(prompt)}>
                {prompt}
              </button>
            ))}
          </div>

          <form
            className="zentom-chat-form"
            onSubmit={(event) => {
              event.preventDefault();
              sendMessage();
            }}
          >
            <input
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder="Ask Zentom..."
              aria-label="Ask Zentom"
            />
            <button type="submit" aria-label="Send message">
              <Send size={16} />
            </button>
          </form>
        </section>
      )}
      
      {showMessage && (
        <div className="speech-bubble">
          <div className="message-text">{message}</div>
          <div className="bubble-tail"></div>
        </div>
      )}
      
      <div className="character-wrapper" onClick={handlePoke}>
        <img src={getImagePath()} alt="Zentom Mascot" className="mascot-image" />
        <div className="shadow"></div>
      </div>

      <button className="control-btn" title="Turn off Zentom Copilot" onClick={handleDisable}>
        <X size={16} />
      </button>

    </div>
  );
}
