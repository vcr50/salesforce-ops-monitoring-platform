document.addEventListener('DOMContentLoaded', () => {

    // Create Mascot DOM Elements
    const container = document.createElement('div');
    container.className = 'mascot-container';
    container.id = 'zentomMascot';

    const chatPanel = document.createElement('section');
    chatPanel.className = 'zentom-chat-panel';
    chatPanel.setAttribute('aria-label', 'Zentom AI bot');
    chatPanel.innerHTML = `
        <div class="zentom-chat-header">
            <div>
                <span class="zentom-chat-kicker">Zentom AI</span>
                <strong>SentinelFlow assistant</strong>
            </div>
            <button class="zentom-chat-close" type="button" aria-label="Close Zentom chat">&times;</button>
        </div>
        <div class="zentom-chat-messages" id="zentomChatMessages">
            <div class="zentom-chat-message bot">Hi, I am Zentom AI. Ask me about SentinelFlow, pricing, integrations, or self-healing.</div>
        </div>
        <div class="zentom-chat-prompts" aria-label="Suggested questions">
            <button type="button" data-prompt="Pricing">Pricing</button>
            <button type="button" data-prompt="Auto-heal">Auto-heal</button>
            <button type="button" data-prompt="Book demo">Book demo</button>
        </div>
        <form class="zentom-chat-form" id="zentomChatForm">
            <input id="zentomChatInput" type="text" placeholder="Ask Zentom..." aria-label="Ask Zentom">
            <button type="submit" aria-label="Send message">Send</button>
        </form>
    `;

    const speechBubble = document.createElement('div');
    speechBubble.className = 'speech-bubble';
    speechBubble.id = 'mascotSpeech';
    
    const speechText = document.createElement('div');
    speechText.id = 'mascotText';
    
    const bubbleTail = document.createElement('div');
    bubbleTail.className = 'bubble-tail';

    speechBubble.appendChild(speechText);
    speechBubble.appendChild(bubbleTail);

    const characterWrapper = document.createElement('div');
    characterWrapper.className = 'character-wrapper';
    characterWrapper.id = 'mascotCharacter';

    const mascotImage = document.createElement('img');
    mascotImage.src = 'assets/mascot/idle.png';
    mascotImage.alt = 'Zentom AI Mascot';
    mascotImage.className = 'mascot-image';
    mascotImage.id = 'mascotImg';

    const shadow = document.createElement('div');
    shadow.className = 'shadow';

    characterWrapper.appendChild(mascotImage);
    characterWrapper.appendChild(shadow);
    
    container.appendChild(chatPanel);
    container.appendChild(speechBubble);
    container.appendChild(characterWrapper);

    document.body.appendChild(container);

    let currentState = 'idle';
    let messageTimeout;
    chatPanel.style.display = 'none';

    // Functions
    function setState(state) {
        currentState = state;
        container.className = `mascot-container mascot-${state}`;
        mascotImage.src = `assets/mascot/${state}.png`;
    }

    function say(text, duration = 3000) {
        speechText.textContent = text;
        speechBubble.classList.add('show');
        
        clearTimeout(messageTimeout);
        messageTimeout = setTimeout(() => {
            speechBubble.classList.remove('show');
        }, duration);
    }

    function getBotReply(question) {
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
    }

    function appendChatMessage(role, text) {
        const messages = document.getElementById('zentomChatMessages');
        const node = document.createElement('div');
        node.className = `zentom-chat-message ${role}`;
        node.textContent = text;
        messages.appendChild(node);
        messages.scrollTop = messages.scrollHeight;
    }

    function sendChatMessage(text) {
        const trimmed = text.trim();
        if (!trimmed) return;
        appendChatMessage('user', trimmed);
        appendChatMessage('bot', getBotReply(trimmed));
        setState('thinking');
        setTimeout(() => setState('idle'), 1200);
    }

    // Event Listeners
    characterWrapper.addEventListener('click', () => {
        chatPanel.style.display = 'block';
        if (currentState === 'idle') setState('excited');
        say('Zentom AI bot is ready. Ask me anything.', 3000);
        setTimeout(() => setState('idle'), 3000);
    });

    chatPanel.querySelector('.zentom-chat-close').addEventListener('click', () => {
        chatPanel.style.display = 'none';
    });

    chatPanel.querySelectorAll('[data-prompt]').forEach((button) => {
        button.addEventListener('click', () => sendChatMessage(button.dataset.prompt));
    });

    chatPanel.querySelector('#zentomChatForm').addEventListener('submit', (event) => {
        event.preventDefault();
        const input = chatPanel.querySelector('#zentomChatInput');
        sendChatMessage(input.value);
        input.value = '';
    });

    // Initial greeting
    setTimeout(() => {
        say('Zentom AI Guardian online.', 4000);
    }, 1000);

    // Random behavior simulation
    setInterval(() => {
        if (Math.random() > 0.8 && currentState === 'idle') {
            setState('thinking');
            setTimeout(() => setState('idle'), 3000);
        }
    }, 10000);
});
