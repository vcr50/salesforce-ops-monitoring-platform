/* ═══════════════════════════════════════════════════════════
   COMMAND MODE ENGINE — "Jarvis for Productivity"
   TomCodex Academy Plugin · Non-breaking · Plugin-style
   ═══════════════════════════════════════════════════════════

   READS from:  window.state, window.globalState, window.TOTAL_DAYS,
                window.START_DATE, window.PHASES
   CALLS:       window.saveState(), window.showToast(), window.addXP(),
                window.updateOverview(), window.buildDailyTable()
   MODIFIES:    window.state.days[n] (same format as quick-save)

   Creates NO new global functions except window.cmdToggle()
   ═══════════════════════════════════════════════════════════ */

(function () {
  "use strict";

  // ─── CONSTANTS ─────────────────────────────────
  // AI calls now routed through window.AI service layer (js/aiService.js)

  const BASE_COMMANDS = [
    { cmd: "start focus", desc: "Start a focus timer (e.g. start focus 25 min on LWC)", icon: "⏱️" },
    { cmd: "log hours", desc: "Log study hours (e.g. log 2 hours on Apex)", icon: "⏳" },
    { cmd: "log pomodoros", desc: "Log completed pomodoros (e.g. log 4 pomodoros)", icon: "🍅" },
    { cmd: "today review", desc: "Generate an AI summary of today's progress", icon: "📊" },
    { cmd: "show streak", desc: "Check your current study streak", icon: "🔥" },
    { cmd: "plan today", desc: "Get an AI suggested study plan", icon: "🧠" },
    { cmd: "navigate overview", desc: "Go to Overview dashboard", icon: "🏠" },
    { cmd: "navigate daily", desc: "Go to Daily Tracker", icon: "📅" },
    { cmd: "navigate notes", desc: "Go to Notes module", icon: "📝" },
    { cmd: "navigate flashcards", desc: "Go to Flashcards module", icon: "🃏" },
    { cmd: "set daily goal", desc: "Set today's hour goal (e.g. set goal 4 hours)", icon: "🎯" }
  ];

  // ─── COMMAND HISTORY STATE ───
  let cmdHistory = [];
  try {
    const saved = localStorage.getItem("cmd_history");
    if (saved) cmdHistory = JSON.parse(saved);
  } catch(e) {}
  let historyIndex = -1;

  // ─── STATE ─────────────────────────────────────
  let isOpen = false;
  let focusInterval = null;
  let focusSecondsLeft = 0;
  let focusTotalSeconds = 0;
  let focusTopic = "";
  let recognition = null;
  let isListening = false;

  // ─── INIT ──────────────────────────────────────
  function init() {
    injectHTML();
    bindEvents();
    initVoice();
  }

  // ─── HTML INJECTION ────────────────────────────
  let orbitOpen = false;

  function injectHTML() {
    // 1. Orbit backdrop (subtle blur when menu open)
    const orbitBd = document.createElement("div");
    orbitBd.id = "cmdOrbitBackdrop";
    orbitBd.className = "cmd-orbit-backdrop";
    document.body.appendChild(orbitBd);

    // 2. Orbital menu container
    const orbit = document.createElement("div");
    orbit.id = "cmdOrbitContainer";
    orbit.className = "cmd-orbit-container";
    orbit.innerHTML = `
      <button class="cmd-orbit-hub" id="cmdOrbitHub" title="Open Menu">
        <div class="cmd-hub-icon cmd-hub-default">
          <svg viewBox="0 0 100 100">
            <ellipse cx="50" cy="50" rx="36" ry="12" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" class="cmd-ring cmd-ring-1" />
            <ellipse cx="50" cy="50" rx="36" ry="12" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" class="cmd-ring cmd-ring-2" />
            <circle cx="50" cy="50" r="12" fill="white" class="cmd-core" />
          </svg>
        </div>
        <div class="cmd-hub-icon cmd-hub-close">
          <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round">
            <path d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>
      </button>
      <button class="cmd-orbit-sat cmd-sat-ai" data-label="AI Coach" id="cmdSatAI">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z" fill="white"/></svg>
      </button>
      <button class="cmd-orbit-sat cmd-sat-cmd" data-label="Command Mode" id="cmdSatCmd">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M6 8a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm0 0v8m0 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm12-8a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm0 0v8m0 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM6 12h12" stroke="white" stroke-width="2" stroke-linecap="round"/></svg>
      </button>
      <button class="cmd-orbit-sat cmd-sat-sf" data-label="Salesforce" id="cmdSatSF">
        <img src="https://upload.wikimedia.org/wikipedia/commons/f/f9/Salesforce.com_logo.svg" alt="SF" style="width:26px;height:26px;filter:brightness(0) invert(1);">
      </button>
      <button class="cmd-orbit-sat cmd-sat-gpt" data-label="ChatGPT" id="cmdSatGPT">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M22.282 9.821a5.985 5.985 0 0 0-.516-4.91 6.046 6.046 0 0 0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a5.998 5.998 0 0 0-3.998 2.9 6.05 6.05 0 0 0 .743 7.097 5.98 5.98 0 0 0 .51 4.911 6.05 6.05 0 0 0 6.515 2.9A5.985 5.985 0 0 0 13.26 24a6.056 6.056 0 0 0 5.772-4.206 5.99 5.99 0 0 0 3.997-2.9 6.056 6.056 0 0 0-.747-7.073zM13.26 22.43a4.476 4.476 0 0 1-2.876-1.04l.141-.081 4.779-2.758a.795.795 0 0 0 .392-.681v-6.737l2.02 1.168a.071.071 0 0 1 .038.052v5.583a4.504 4.504 0 0 1-4.494 4.494zM3.6 18.304a4.47 4.47 0 0 1-.535-3.014l.142.085 4.783 2.759a.771.771 0 0 0 .78 0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 1-6.14-1.646zM2.34 7.896a4.485 4.485 0 0 1 2.366-1.973V11.6a.766.766 0 0 0 .388.676l5.815 3.355-2.02 1.168a.076.076 0 0 1-.071 0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 3.855l-5.833-3.387L15.119 7.2a.076.076 0 0 1 .071 0l4.83 2.791a4.494 4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 0-.407-.667zm2.01-3.023l-.141-.085-4.774-2.782a.776.776 0 0 0-.785 0L9.409 9.23V6.897a.066.066 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 6.68 4.66zm-12.64 4.135l-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.795.795 0 0 0-.393.681zm1.097-2.365l2.602-1.5 2.607 1.5v2.999l-2.597 1.5-2.607-1.5z"/></svg>
      </button>
      <button class="cmd-orbit-sat cmd-sat-claude" data-label="Claude" id="cmdSatClaude">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M4.709 15.955l4.397-2.398-.002-4.892L4.86 6.45l-.165.096v9.282l.015.127zm7.294-10.391l4.263 2.395-4.395 2.398-4.378-2.39 4.262-2.395.248-.008zm5.026 2.789v4.7l-4.246 2.477V10.76l4.233-2.404.013-.003zm-5.281 12.595l4.525-2.397-4.396-2.398-4.378 2.39 4.249 2.405zm5.278-2.776l.163-.096V8.792l-4.41 2.509.002 4.892 4.245-2.022zm-10.304.379l4.245 2.022V15.88l-4.415-2.503.009-.003.161 5.177z"/></svg>
      </button>
      <button class="cmd-orbit-sat cmd-sat-gemini" data-label="Gemini" id="cmdSatGemini">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M12 0C12 0 12 8 6 12c6 4 6 12 6 12s0-8 6-12c-6-4-6-12-6-12z"/></svg>
      </button>
    `;
    document.body.appendChild(orbit);

    // 3. Backdrop for command palette
    const backdrop = document.createElement("div");
    backdrop.id = "cmdBackdrop";
    backdrop.className = "cmd-backdrop";
    document.body.appendChild(backdrop);

    // 4. Command Palette
    const palette = document.createElement("div");
    palette.id = "cmdPalette";
    palette.className = "cmd-palette";
    palette.innerHTML = `
      <div id="cmdToastContainer" class="cmd-toast-container"></div>
      <div class="cmd-input-row">
        <span class="cmd-icon">⚡</span>
        <div class="cmd-input-wrapper">
          <div id="cmdInputGhost" class="cmd-input-ghost"></div>
          <input type="text" id="cmdInput" class="cmd-input"
                 placeholder="Type a command... (e.g. start focus 25 min)"
                 autocomplete="off" spellcheck="false" />
        </div>
        <button id="cmdVoiceBtn" class="cmd-voice-btn" title="Voice Input">🎙️</button>
        <div class="cmd-kbd-hint">
          <span class="cmd-kbd">Ctrl</span>
          <span class="cmd-kbd">K</span>
        </div>
      </div>
      <div id="cmdPreview" class="cmd-preview-bar cmd-hidden"></div>
      <div id="cmdSuggestions" class="cmd-suggestions"></div>
      <div id="cmdResponse" class="cmd-response"></div>
      <div class="cmd-footer">
        <span>⚡ Command Mode</span>
        <div class="cmd-footer-actions">
           <span><span class="cmd-kbd">↑↓</span> History</span>
           <span><span class="cmd-kbd">⇥</span> Complete</span>
          <span><span class="cmd-kbd">↵</span> Run</span>
          <span><span class="cmd-kbd">Esc</span> Close</span>
        </div>
      </div>
    `;
    document.body.appendChild(palette);

    // 5. Focus Mode Overlay
    const focus = document.createElement("div");
    focus.id = "cmdFocusOverlay";
    focus.className = "cmd-focus-overlay";
    focus.innerHTML = `
      <div class="cmd-focus-particles" id="cmdFocusParticles"></div>
      <div class="cmd-focus-content">
        <div class="cmd-focus-topic" id="cmdFocusTopic">DEEP WORK</div>
        <div class="cmd-focus-timer" id="cmdFocusTimer">25:00</div>
        <div class="cmd-focus-label">Stay focused. You're doing great.</div>
        <div class="cmd-focus-progress">
          <div class="cmd-focus-progress-fill" id="cmdFocusBar" style="width:100%"></div>
        </div>
        <div class="cmd-focus-actions">
          <button class="cmd-focus-btn cmd-focus-btn-primary" id="cmdFocusPauseBtn">⏸ Pause</button>
          <button class="cmd-focus-btn cmd-focus-btn-ghost" id="cmdFocusEndBtn">End Session</button>
        </div>
      </div>
    `;
    document.body.appendChild(focus);

    // Generate ambient particles
    const particlesContainer = document.getElementById("cmdFocusParticles");
    for (let i = 0; i < 30; i++) {
      const p = document.createElement("div");
      p.className = "cmd-particle";
      p.style.left = Math.random() * 100 + "%";
      p.style.animationDuration = 6 + Math.random() * 10 + "s";
      p.style.animationDelay = Math.random() * 8 + "s";
      p.style.width = p.style.height = 2 + Math.random() * 4 + "px";
      const colors = [
        "rgba(96,165,250,0.4)",
        "rgba(167,139,250,0.3)",
        "rgba(244,114,182,0.3)",
        "rgba(52,211,153,0.3)",
      ];
      p.style.background = colors[Math.floor(Math.random() * colors.length)];
      particlesContainer.appendChild(p);
    }
  }

  // ─── ORBITAL MENU ─────────────────────────────
  function toggleOrbit() {
    orbitOpen = !orbitOpen;
    const container = document.getElementById("cmdOrbitContainer");
    const hub = document.getElementById("cmdOrbitHub");
    const bd = document.getElementById("cmdOrbitBackdrop");

    if (orbitOpen) {
      container.classList.add("cmd-orbit-open");
      hub.classList.add("cmd-orbit-active");
      bd.classList.add("cmd-orbit-bd-open");
    } else {
      container.classList.remove("cmd-orbit-open");
      hub.classList.remove("cmd-orbit-active");
      bd.classList.remove("cmd-orbit-bd-open");
    }
  }

  function closeOrbit() {
    if (!orbitOpen) return;
    orbitOpen = false;
    const container = document.getElementById("cmdOrbitContainer");
    const hub = document.getElementById("cmdOrbitHub");
    const bd = document.getElementById("cmdOrbitBackdrop");
    container.classList.remove("cmd-orbit-open");
    hub.classList.remove("cmd-orbit-active");
    bd.classList.remove("cmd-orbit-bd-open");
  }

  // ─── EVENT BINDING ─────────────────────────────
  function bindEvents() {
    // Hub button → toggle orbital menu
    document.getElementById("cmdOrbitHub").addEventListener("click", toggleOrbit);

    // Orbit backdrop → close
    document.getElementById("cmdOrbitBackdrop").addEventListener("click", closeOrbit);

    // Satellite: AI Coach → open existing AI chat widget
    document.getElementById("cmdSatAI").addEventListener("click", () => {
      closeOrbit();
      const widget = document.getElementById("aiCoachWidget");
      if (widget) {
        widget.classList.toggle("open");
        if (widget.classList.contains("open")) {
          setTimeout(() => document.getElementById("aiInput")?.focus(), 100);
        }
      }
    });

    // Satellite: Command Mode → open command palette
    document.getElementById("cmdSatCmd").addEventListener("click", () => {
      closeOrbit();
      open();
    });

    function openExternalApp(url) {
      closeOrbit();
      const a = document.createElement('a');
      a.href = url;
      // On desktop, open in new tab. 
      // On mobile, open in current tab -> this allows iOS Universal Links and Android App Links to intercept the URL and open the native apps directly!
      if (!/Mobi|Android|iPhone|iPad/i.test(navigator.userAgent)) {
        a.target = "_blank";
      }
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }

    // Satellite: Salesforce Login
    document.getElementById("cmdSatSF").addEventListener("click", () => {
      openExternalApp("https://login.salesforce.com");
    });

    // Satellite: ChatGPT
    document.getElementById("cmdSatGPT").addEventListener("click", () => {
      openExternalApp("https://chatgpt.com/");
    });

    // Satellite: Claude
    document.getElementById("cmdSatClaude").addEventListener("click", () => {
      openExternalApp("https://claude.ai/");
    });

    // Satellite: Gemini
    document.getElementById("cmdSatGemini").addEventListener("click", () => {
      openExternalApp("https://gemini.google.com/");
    });

    // Command palette backdrop click to close
    document.getElementById("cmdBackdrop").addEventListener("click", close);

    // Keyboard shortcut: Ctrl+K or Cmd+K
    document.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault();
        closeOrbit();
        toggle();
      }
      if (e.key === "Escape") {
        if (isOpen) close();
        if (orbitOpen) closeOrbit();
      }
    });

    // Enter to execute
    // ── Input Live Parsing & Auto-Complete ──
    const inputEl = document.getElementById("cmdInput");
    const ghostEl = document.getElementById("cmdInputGhost");
    const suggEl = document.getElementById("cmdSuggestions");

    // Dynamic Context Building
    function buildContextualSuggestions() {
      const hour = new Date().getHours();
      let suggestions = [...BASE_COMMANDS];
      
      // Contextual sorting based on time of day
      if (hour < 12) {
        // Morning -> prioritize planning and focus
        suggestions.sort((a,b) => (a.cmd.includes('plan') || a.cmd.includes('focus')) ? -1 : 1);
      } else if (hour > 17) {
        // Evening -> prioritize logging and review
        suggestions.sort((a,b) => (a.cmd.includes('log') || a.cmd.includes('review')) ? -1 : 1);
      }

      return suggestions;
    }

    function renderSuggestions(list, isVertical = false) {
      if (isVertical) suggEl.classList.add("cmd-list-mode");
      else suggEl.classList.remove("cmd-list-mode");

      suggEl.innerHTML = list.map((c, i) => `
        <div class="cmd-chip ${i===0 && isVertical ? 'cmd-selected' : ''}" data-cmd="${c.cmd}">
          <span style="font-size:16px;">${c.icon}</span> 
          <div style="display:flex; flex-direction:column; align-items:flex-start;">
            <span style="font-weight:600;">${c.cmd}</span>
            ${isVertical ? `<span style="font-size:11px; color:var(--text-muted);">${c.desc}</span>` : ''}
          </div>
        </div>
      `).join("");

      // Re-bind chips
      suggEl.querySelectorAll(".cmd-chip").forEach((chip) => {
        chip.addEventListener("click", () => {
          const cmdStr = chip.dataset.cmd;
          const parsed = parseCommand(cmdStr);
          if (parsed.confidence === 1.0) {
            inputEl.value = cmdStr;
            executeCommand(cmdStr);
          } else {
            // Needs arguments -> Populate input, add space, and focus
            inputEl.value = cmdStr + " ";
            debouncedPreview(inputEl.value);
            inputEl.focus();
            suggEl.classList.add("cmd-hidden");
          }
        });
      });
    }

    inputEl.addEventListener("input", (e) => {
      const text = e.target.value.toLowerCase();
      
      // Update UI preview bar
      debouncedPreview(text);

      if (!text) {
        ghostEl.innerText = "";
        renderSuggestions(buildContextualSuggestions(), false);
        return;
      }
      
      // Auto-complete match
      const matching = BASE_COMMANDS.filter(cmd => cmd.cmd.startsWith(text));
      if (matching.length > 0) {
        // Ghost text rendering
        const full = matching[0].cmd;
        ghostEl.innerHTML = `<span style="opacity:0">${text}</span>${full.substring(text.length)}`;
        renderSuggestions(matching, true);
      } else {
        ghostEl.innerText = "";
        // Fuzzy search for other
        const fuzzy = BASE_COMMANDS.filter(cmd => cmd.cmd.includes(text));
        renderSuggestions(fuzzy, true);
      }
    });

    inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        const text = e.target.value.trim();
        if (text) executeCommand(text);
      }
      else if (e.key === "Tab") {
        // Auto-complete to the ghost text if present
        e.preventDefault();
        if (ghostEl.innerText) {
          inputEl.value = ghostEl.innerText.replace(/\s+/g, ' ').trim();
          ghostEl.innerText = "";
          const text = inputEl.value.toLowerCase();
          const matching = BASE_COMMANDS.filter(cmd => cmd.cmd.startsWith(text));
          renderSuggestions(matching, true);
        }
      }
      else if (e.key === "ArrowUp") {
        e.preventDefault();
        if (cmdHistory.length > 0) {
          historyIndex = Math.min(historyIndex + 1, cmdHistory.length - 1);
          inputEl.value = cmdHistory[historyIndex];
          ghostEl.innerText = "";
        }
      }
      else if (e.key === "ArrowDown") {
        e.preventDefault();
        if (historyIndex > 0) {
          historyIndex--;
          inputEl.value = cmdHistory[historyIndex];
        } else {
          historyIndex = -1;
          inputEl.value = "";
        }
        ghostEl.innerText = "";
      }
    });

    // Quick command chips
    document.querySelectorAll(".cmd-chip").forEach((chip) => {
      chip.addEventListener("click", () => {
        const cmd = chip.dataset.cmd;
        document.getElementById("cmdInput").value = cmd;
        executeCommand(cmd);
      });
    });

    // Voice
    document
      .getElementById("cmdVoiceBtn")
      .addEventListener("click", toggleVoice);

    // Focus mode buttons
    document
      .getElementById("cmdFocusPauseBtn")
      .addEventListener("click", toggleFocusPause);
    document
      .getElementById("cmdFocusEndBtn")
      .addEventListener("click", endFocusSession);
  }

  // ─── OPEN / CLOSE / TOGGLE ─────────────────────
  function open() {
    isOpen = true;
    document.getElementById("cmdBackdrop").classList.add("cmd-open");
    document.getElementById("cmdPalette").classList.add("cmd-open");
    document.getElementById("cmdResponse").innerHTML = "";
    document.getElementById("cmdSuggestions").classList.remove("cmd-hidden");
    
    // Inject dynamic, context-aware default chips on load
    const contextSujects = (() => {
      const hour = new Date().getHours();
      let suggestions = [...BASE_COMMANDS];
      if (hour < 12) suggestions.sort((a,b) => (a.cmd.includes('plan') || a.cmd.includes('focus')) ? -1 : 1);
      else if (hour > 17) suggestions.sort((a,b) => (a.cmd.includes('log') || a.cmd.includes('review')) ? -1 : 1);
      return suggestions.slice(0, 6);
    })();
    const suggEl = document.getElementById("cmdSuggestions");
    suggEl.classList.remove("cmd-list-mode");
    suggEl.innerHTML = contextSujects.map((c) => `<button class="cmd-chip" data-cmd="${c.cmd}">${c.icon} ${c.cmd}</button>`).join("");
    suggEl.querySelectorAll(".cmd-chip").forEach((chip) => {
      chip.addEventListener("click", () => {
        const cmdStr = chip.dataset.cmd;
        const parsed = parseCommand(cmdStr);
        const inputEl = document.getElementById("cmdInput");
        if (parsed.confidence === 1.0) {
          inputEl.value = cmdStr;
          executeCommand(cmdStr);
        } else {
          inputEl.value = cmdStr + " ";
          debouncedPreview(inputEl.value);
          inputEl.focus();
        }
      });
    });

    const input = document.getElementById("cmdInput");
    input.value = "";
    document.getElementById("cmdInputGhost").innerText = "";
    historyIndex = -1;
    setTimeout(() => input.focus(), 100);
  }

  function close() {
    isOpen = false;
    document.getElementById("cmdBackdrop").classList.remove("cmd-open");
    document.getElementById("cmdPalette").classList.remove("cmd-open");
    if (isListening) stopVoice();
  }

  function toggle() {
    isOpen ? close() : open();
  }

  // Expose globally for manual trigger
  window.cmdToggle = toggle;

  // ─── COMMAND PARSER ────────────────────────────
  
  let previewTimeout;
  function debouncedPreview(text) {
    clearTimeout(previewTimeout);
    const previewEl = document.getElementById("cmdPreview");
    if (!previewEl) return;
    
    if (!text.trim()) {
      previewEl.classList.add("cmd-hidden");
      return;
    }

    previewTimeout = setTimeout(() => {
      const parsed = parseCommand(text);
      previewEl.classList.remove("cmd-hidden", "cmd-warning", "cmd-ai");
      
      if (parsed.confidence === 1.0) {
        previewEl.innerHTML = `<span>⚡</span> <span>${parsed.message}</span>`;
      } else if (parsed.confidence >= 0.6) {
        previewEl.classList.add("cmd-warning");
        previewEl.innerHTML = `<span>⚠️</span> <span>${parsed.message}</span>`;
      } else {
        previewEl.classList.add("cmd-ai");
        previewEl.innerHTML = `<span>🤖</span> <span>${parsed.message}</span>`;
      }
    }, 150);
  }

  // Rule-based intent extraction yielding { intent, confidence, data, message }
  function parseCommand(text) {
    const lower = text.toLowerCase().trim();

    if (lower.length < 2) {
      return { intent: "unknown", confidence: 0.1, message: "Keep typing..." };
    }

    // ── FOCUS / STUDY SESSION ──
    const focusMatch = lower.match(
      /(?:start|begin|launch)\s+(?:focus|study|session|work|deep\s*work)(?:\s+(?:for\s+)?(\d+)\s*(?:min(?:utes?)?|m))?(?:\s+(?:on\s+)?(.+))?/
    );
    if (focusMatch || lower === "start study" || lower === "start focus") {
      const duration = focusMatch?.[1] ? parseInt(focusMatch[1]) : 25;
      const topic = focusMatch?.[2]?.trim() || "";
      return {
        intent: "start_focus", confidence: 1.0, data: { duration, topic },
        message: `Will start ${duration} min focus session${topic ? " on " + topic : ""}.`
      };
    }
    if (lower.startsWith("start") || lower.includes("focus session")) {
      return { intent: "unknown", confidence: 0.7, message: "Did you mean 'start focus 25 min'?" };
    }

    // ── LOG HOURS ──
    const logMatch = lower.match(
      /(?:log|add|save|record)\s+(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\s*(?:(?:of|for|on|in)\s+)?(.+)?/
    );
    if (logMatch) {
      return {
        intent: "log_hours", confidence: 1.0, 
        data: { hours: parseFloat(logMatch[1]), topic: logMatch[2]?.trim() || "" },
        message: `Will log ${logMatch[1]} hours${logMatch[2] ? " on " + logMatch[2] : ""}.`
      };
    }

    // ── LOG POMODOROS ──
    const pomoLogMatch = lower.match(/(?:log|add|save)\s+(\d+)\s*(?:pomodoros?|pomos?|🍅)/);
    if (pomoLogMatch) {
      return {
        intent: "log_pomodoros", confidence: 1.0, data: { count: parseInt(pomoLogMatch[1]) },
        message: `Will log ${pomoLogMatch[1]} pomodoros.`
      };
    }
    if (lower.startsWith("log")) {
      return { intent: "unknown", confidence: 0.8, message: "Specify time: 'log 2 hours' or 'log 4 pomodoros'." };
    }

    // ── SHOW PROGRESS / STREAK / SUMMARY ──
    if (/(?:show|view|check|my)\s*(?:progress|stats|overview)/.test(lower)) {
      return { intent: "show_progress", confidence: 1.0, message: "Will open your progress dashboard." };
    }
    if (/(?:show|what(?:'s| is)|check|my)\s*(?:my\s+)?streak/.test(lower)) {
      return { intent: "show_streak", confidence: 1.0, message: "Will compute your current streak." };
    }
    if (/(?:show|my)\s*(?:today|daily)(?:'s)?\s*(?:summary|review)/.test(lower) || lower === "night review") {
      return { intent: "today_summary", confidence: 1.0, message: "Will generate your end of day summary." };
    }

    // ── PLAN / WHAT TO STUDY ──
    if (/(?:what|suggest|plan|recommend).+(?:study|learn|focus)/.test(lower) || lower.includes("study plan") || lower === "plan today") {
      return { intent: "ai_plan", confidence: 1.0, message: "Will generate a tailored study plan for today." };
    }

    // ── NAVIGATE ──
    const navMatch = lower.match(/(?:go\s*(?:to)?|open|navigate\s*(?:to)?|switch\s*(?:to)?)\s+(.+)/);
    if (navMatch) {
      const target = navMatch[1].trim();
      const navMap = {
        overview: ["overview", "home", "dashboard"],
        daily: ["daily", "tracker", "tracking"],
        notes: ["notes", "note"],
        flashcards: ["flashcards", "cards", "quiz"],
        calendar: ["calendar", "schedule"],
        resources: ["resources", "links"]
      };
      for (const [section, keywords] of Object.entries(navMap)) {
        if (keywords.some((kw) => target.includes(kw))) {
          return { intent: "navigate", confidence: 1.0, data: { section }, message: `Will switch to ${section}.` };
        }
      }
      return { intent: "unknown", confidence: 0.6, message: `Could not find section '${target}'.` };
    }

    // ── SET GOAL ──
    const goalMatch = lower.match(/(?:set|change|update)\s+(?:my\s+)?(?:daily\s+)?goal\s+(?:to\s+)?(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)?/);
    if (goalMatch) {
      return { intent: "set_goal", confidence: 1.0, data: { hours: parseFloat(goalMatch[1]) }, message: `Will set today's goal to ${goalMatch[1]}h.` };
    }

    // ── UNRECOGNIZED → send to AI ──
    if (lower.length < 5) {
      return { intent: "unknown", confidence: 0.4, message: "Keep typing to ask a question..." };
    }
    return { intent: "ai_freeform", confidence: 0.1, data: { text }, message: "Press Enter to ask AI Coach." };
  }

  // ─── COMMAND EXECUTOR ──────────────────────────
  async function executeCommand(text) {
    const responseEl = document.getElementById("cmdResponse");
    const suggestionsEl = document.getElementById("cmdSuggestions");
    const previewEl = document.getElementById("cmdPreview");
    suggestionsEl.classList.add("cmd-hidden");
    if(previewEl) previewEl.classList.add("cmd-hidden");
    responseEl.innerHTML = "";

    const parsed = parseCommand(text);

    // Confidence Checks
    if (parsed.confidence >= 0.5 && parsed.confidence < 1.0) {
      // Mid confidence - bounce user input
      const inputEl = document.getElementById("cmdInput");
      inputEl.classList.add("cmd-error-shake");
      setTimeout(() => inputEl.classList.remove("cmd-error-shake"), 400);
      return; // Reject execution
    }

    switch (parsed.intent) {
      case "start_focus":
        close();
        startFocusSession(parsed.data.duration, parsed.data.topic);
        break;

      case "log_hours":
        execLogHours(parsed.data.hours, parsed.data.topic, responseEl);
        break;

      case "log_pomodoros":
        execLogPomodoros(parsed.data.count, responseEl);
        break;

      case "show_progress":
        execShowProgress(responseEl);
        break;

      case "show_streak":
        execShowStreak(responseEl);
        break;

      case "today_summary":
        execTodaySummary(responseEl);
        break;

      case "ai_plan":
        await execAIPlan(responseEl);
        break;

      case "navigate":
        execNavigate(parsed.data.section, responseEl);
        break;

      case "set_goal":
        execSetGoal(parsed.data.hours, responseEl);
        break;

      case "ai_freeform":
        try {
          // Inline loading indicator
          showLoading(responseEl, "Analyzing request...");
          
          let result;
          if (window.AI && typeof window.AI.generate === 'function') {
            result = await window.AI.generate(
              parsed.data.text,
              'You are an AI assistant for a Salesforce developer studying. Be extremely concise.'
            );
          } else {
            // Fallback if aiService not loaded
            let encodedText = encodeURIComponent(
              `You are an AI assistant for a Salesforce developer studying. Be extremely concise. Answer this: ${parsed.data.text}`
            );
            let response = await fetch(`https://text.pollinations.ai/${encodedText}`);
            if (!response.ok) throw new Error("API Failure");
            result = await response.text();
          }
          result = (result || '').trim();
          
          // Smart Routing Logic: Check length AND multi-line breaks
          if (result.length > 100 || result.includes("\n")) {
            // Complex response -> Send to full AI Coach
            showResult(responseEl, "🤖", "Opening AI Coach...", "Detailed response incoming. Generating full panel.");
            setTimeout(() => {
              close();
              if (typeof window.openAICoach === "function") {
                window.openAICoach(parsed.data.text);
              }
            }, 800);
          } else {
            // Short response -> Show inline
            showResult(responseEl, "🤖", "AI Insight", result);
          }
        } catch(e) {
          showResult(responseEl, "❌", "AI Error", "Failed to connect to AI engine. Try again.");
        }
        break;

      case "toggle_dark":
        execToggleDark(responseEl);
        break;

      case "save":
        execSave(responseEl);
        break;

      case "help":
        execHelp(responseEl);
        break;

      case "unknown":
        showResult(responseEl, "❌", "Clarification Needed", parsed.message);
        break;

      default:
        showResult(responseEl, "❌", "Command Failed", "I couldn't process that. Try rephrasing.");
        break;
    }

    // Store to history
    if (!cmdHistory.includes(text)) {
      cmdHistory.unshift(text);
      if (cmdHistory.length > 10) cmdHistory.pop();
      localStorage.setItem("cmd_history", JSON.stringify(cmdHistory));
    }
    historyIndex = -1;

    // Clear UI state post-execution
    document.getElementById("cmdInput").value = "";
    document.getElementById("cmdInputGhost").innerText = "";
  }

  // ─── EXECUTION FEEDBACK UI (TOAST) ─────────────
  function showExecutionToast(message, icon = "✅") {
    const container = document.getElementById("cmdToastContainer");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = "cmd-toast";
    toast.innerHTML = `<span style="font-size:18px;">${icon}</span> <span>${message}</span>`;
    
    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add("cmd-toast-exit");
      setTimeout(() => toast.remove(), 350);
    }, 3000);
  }

  // ─── EXECUTORS ─────────────────────────────────

  function execLogHours(hours, topic, el) {
    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded yet.");

    const td = getTodayDay();
    if (!td) return showResult(el, "⚠️", "Not in Journey Range", "Your journey hasn't started or has ended.");

    const existing = state.days[td] || {};
    const oldHours = existing.hours || 0;

    state.days[td] = {
      ...existing,
      hours: hours,
      topics: topic
        ? (existing.topics ? existing.topics + ", " + topic : topic)
        : existing.topics || "",
    };

    if (hours > oldHours && typeof window.addXP === "function") {
      window.addXP(Math.round((hours - oldHours) * 25), "Command: Log Hours");
    }

    safeCall("saveState");
    safeCall("buildDailyTable");
    safeCall("updateOverview");

    showExecutionToast(`Logged ${hours} hours ${topic ? "on " + topic : ""}`);
    
    showResult(
      el,
      "✅",
      `Logged ${hours}h${topic ? " for " + topic : ""}`,
      `Day ${td} updated. ${topic ? "Topic: <strong>" + topic + "</strong>." : ""} Your data is saved to cloud.`
    );
  }

  function execLogPomodoros(count, el) {
    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded yet.");

    const td = getTodayDay();
    if (!td) return showResult(el, "⚠️", "Not in Journey Range", "Your journey hasn't started or has ended.");

    const existing = state.days[td] || {};
    state.days[td] = {
      ...existing,
      pomodoros: (existing.pomodoros || 0) + count,
    };

    safeCall("saveState");
    safeCall("buildDailyTable");
    safeCall("updateOverview");

    showExecutionToast(`Logged ${count} Pomodoros`, "🍅");

    showResult(
      el,
      "🍅",
      `Logged ${count} Pomodoro(s)`,
      `Total pomodoros updated for Day ${td}.`
    );
  }

  function execShowProgress(el) {
    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded yet.");

    let completed = 0, totalHours = 0, totalPomo = 0;
    const totalDays = window.TOTAL_DAYS || 55;

    for (let d = 1; d <= totalDays; d++) {
      const e = state.days[d] || {};
      if (e.completed) completed++;
      totalHours += parseFloat(e.hours || 0);
      totalPomo += parseInt(e.pomodorosCompleted || 0, 10);
    }

    const pct = Math.round((completed / totalDays) * 100);
    const streak = calcCurrentStreak();

    el.innerHTML = `
      <div class="cmd-result" style="flex-direction:column;">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px;">
          <span class="cmd-result-icon">📊</span>
          <span class="cmd-result-title">Your Progress Dashboard</span>
        </div>
        <div class="cmd-stats-grid">
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${completed}/${totalDays}</div>
            <div class="cmd-stat-label">Days Done</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${totalHours.toFixed(1)}h</div>
            <div class="cmd-stat-label">Total Hours</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${totalPomo}</div>
            <div class="cmd-stat-label">Pomodoros</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${pct}%</div>
            <div class="cmd-stat-label">Progress</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val" style="color:#f59e0b;">🔥 ${streak}</div>
            <div class="cmd-stat-label">Day Streak</div>
          </div>
        </div>
      </div>
    `;
  }

  function execShowStreak(el) {
    const streak = calcCurrentStreak();
    const bestStreak = calcBestStreak();

    showResult(
      el,
      "🔥",
      `Current Streak: ${streak} day${streak !== 1 ? "s" : ""}`,
      `Best streak: <strong>${bestStreak} days</strong>. ${
        streak >= 3
          ? "You're on fire! Keep it going! 💪"
          : streak > 0
            ? "Good start! Stay consistent! 📈"
            : "Start logging hours today to build your streak! 🚀"
      }`
    );
  }

  function execTodaySummary(el) {
    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded yet.");

    const td = getTodayDay();
    if (!td) return showResult(el, "⚠️", "No Data", "Not in journey range.");

    const entry = state.days[td] || {};
    const hours = entry.hours || 0;
    const pomos = entry.pomodorosCompleted || 0;
    const topics = entry.topics || "None logged";
    const goal = state.goalHours || 4;
    const goalPct = Math.min(100, Math.round((hours / goal) * 100));
    const streak = calcCurrentStreak();

    const phase = getCurrentPhase(td);

    el.innerHTML = `
      <div class="cmd-result" style="flex-direction:column;">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px;">
          <span class="cmd-result-icon">🌙</span>
          <span class="cmd-result-title">Day ${td} Summary — ${phase}</span>
        </div>
        <div class="cmd-result-desc" style="margin-bottom:12px;">
          ${hours > 0
            ? `You studied <strong>${hours}h</strong> today (${goalPct}% of your ${goal}h goal). Topics: <strong>${topics}</strong>.`
            : "No hours logged yet today. There's still time! ⏰"
          }
          ${pomos > 0 ? `<br>🍅 ${pomos} Pomodoro${pomos > 1 ? "s" : ""} completed.` : ""}
          <br>🔥 Streak: <strong>${streak} day${streak !== 1 ? "s" : ""}</strong>
        </div>
        <div class="cmd-stats-grid">
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${hours}h</div>
            <div class="cmd-stat-label">Hours Today</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${goalPct}%</div>
            <div class="cmd-stat-label">Goal Hit</div>
          </div>
          <div class="cmd-stat-card">
            <div class="cmd-stat-val">${pomos}</div>
            <div class="cmd-stat-label">Pomodoros</div>
          </div>
        </div>
      </div>
    `;
  }

  async function execAIPlan(el) {
    showLoading(el, "Generating your daily plan...");

    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded yet.");

    const td = getTodayDay();
    const totalDays = window.TOTAL_DAYS || 55;
    const phase = getCurrentPhase(td || 1);
    const streak = calcCurrentStreak();
    const goal = state.goalHours || 4;

    // Calculate hours this week
    let weekHours = 0;
    if (td) {
      const weekStart = Math.max(1, td - (new Date().getDay() || 7) + 1);
      for (let d = weekStart; d <= td; d++) {
        weekHours += parseFloat((state.days[d] || {}).hours || 0);
      }
    }

    // Build pending todos
    const pendingTodos = (state.todos || [])
      .filter((t) => !t.done)
      .slice(0, 5)
      .map((t) => t.text)
      .join(", ") || "None";

    const prompt = `You are a study coach for a Salesforce learner.

Context:
- Current day: Day ${td || "?"} of ${totalDays}
- Phase: ${phase}
- Hours this week: ${weekHours}h
- Daily goal: ${goal}h
- Streak: ${streak} days
- Pending tasks: ${pendingTodos}

Generate a SHORT, actionable daily plan with 3-4 time blocks.
Format each as: [emoji] [Time] — [Task] ([Duration])
End with one motivational line.
Keep it under 8 lines total. Be specific to Salesforce topics.`;

    try {
      const res = await fetch(
        POLLINATIONS_URL + encodeURIComponent(prompt) + "?model=openai"
      );
      if (!res.ok) throw new Error("AI Error");
      let reply = await res.text();

      el.innerHTML = "";
      showResult(
        el,
        "📅",
        "Your Daily Plan",
        reply
          .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
          .replace(/\n/g, "<br>")
      );
    } catch (err) {
      el.innerHTML = "";
      showResult(
        el,
        "⚠️",
        "AI Unavailable",
        "Couldn't generate plan. Try again or check your connection."
      );
    }
  }

  function execNavigate(section, el) {
    // Simulate clicking the nav item
    const navItem = document.querySelector(`.nav-item[data-section="${section}"]`);
    if (navItem) {
      navItem.click();
      close();
      if (typeof window.showToast === "function") {
        window.showToast(`Navigated to ${section.charAt(0).toUpperCase() + section.slice(1)} 📍`);
      }
    } else {
      showResult(el, "⚠️", "Section Not Found", `Couldn't find section "${section}".`);
    }
  }

  function execSetGoal(hours, el) {
    const state = window.state;
    if (!state) return showResult(el, "❌", "Error", "App state not loaded.");

    state.goalHours = hours;
    safeCall("saveState");
    safeCall("updateOverview");

    showResult(
      el,
      "🎯",
      `Daily Goal Set to ${hours}h`,
      "Your new target is reflected on the dashboard."
    );
  }

  function execToggleDark(el) {
    const toggle = document.getElementById("darkToggle");
    if (toggle) {
      toggle.click();
      const isDark = document.documentElement.getAttribute("data-theme") === "dark";
      showResult(
        el,
        isDark ? "🌙" : "☀️",
        isDark ? "Dark Mode Enabled" : "Light Mode Enabled",
        "Theme switched successfully."
      );
    }
  }

  async function execSave(el) {
    showLoading(el, "Saving all data...");
    if (typeof window.saveState === "function") {
      await window.saveState();
    }
    el.innerHTML = "";
    showResult(el, "💾", "All Data Saved", "Your progress has been synced to the cloud.");
  }

  function execHelp(el) {
    el.innerHTML = `
      <div class="cmd-result" style="flex-direction:column;">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
          <span class="cmd-result-icon">📖</span>
          <span class="cmd-result-title">Available Commands</span>
        </div>
        <div class="cmd-result-desc" style="line-height:2;">
          <strong>Focus:</strong> <code>start focus 25 min apex</code>, <code>start study</code><br>
          <strong>Log:</strong> <code>log 2 hours apex</code>, <code>log 3 pomodoros</code><br>
          <strong>Plan:</strong> <code>what should I study today</code>, <code>plan</code><br>
          <strong>View:</strong> <code>show my progress</code>, <code>show streak</code>, <code>show today summary</code><br>
          <strong>Navigate:</strong> <code>go to notes</code>, <code>open calendar</code>, <code>show flashcards</code><br>
          <strong>Settings:</strong> <code>set goal to 5 hours</code>, <code>dark mode</code><br>
          <strong>System:</strong> <code>save</code>, <code>help</code><br>
          <br>
          💡 <em>Or type anything — AI will try to understand it!</em>
        </div>
      </div>
    `;
  }

  async function execAIFreeform(text, el) {
    showLoading(el, "Thinking...");

    const systemPrompt = `You are Tomcodex Command Assistant, a concise productivity AI for a Salesforce learner.
The user just typed a command you should try to help with.
If it's a study question, give a brief answer (max 4 lines).
If it seems like a command you can't parse, suggest the closest valid command.
Valid commands: start focus, log hours, show progress, show streak, plan, go to [section], set goal, dark mode, save.
Be ultra-concise. Use emoji. Act like Jarvis.`;

    try {
      const url = `${POLLINATIONS_URL}${encodeURIComponent(text)}?system=${encodeURIComponent(systemPrompt)}&model=openai`;
      const res = await fetch(url);
      if (!res.ok) throw new Error("AI error");
      const reply = await res.text();

      el.innerHTML = "";
      showResult(
        el,
        "🤖",
        "AI Response",
        reply
          .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
          .replace(/`(.+?)`/g, "<code>$1</code>")
          .replace(/\n/g, "<br>")
      );
    } catch {
      el.innerHTML = "";
      showResult(
        el,
        "⚠️",
        "Couldn't Understand",
        'Try commands like <code>start focus</code>, <code>log 2 hours</code>, or type <code>help</code> for full list.'
      );
    }
  }

  // ─── FOCUS MODE ────────────────────────────────
  function startFocusSession(minutes, topic) {
    focusTotalSeconds = minutes * 60;
    focusSecondsLeft = focusTotalSeconds;
    focusTopic = topic || "Deep Work";

    const overlay = document.getElementById("cmdFocusOverlay");
    overlay.classList.add("cmd-active");

    document.getElementById("cmdFocusTopic").textContent =
      focusTopic.toUpperCase();
    document.getElementById("cmdFocusPauseBtn").textContent = "⏸ Pause";

    updateFocusDisplay();

    focusInterval = setInterval(() => {
      focusSecondsLeft--;
      updateFocusDisplay();

      if (focusSecondsLeft <= 0) {
        completeFocusSession();
      }
    }, 1000);

    if (typeof window.showToast === "function") {
      window.showToast(`Focus: ${minutes} min ${topic ? "→ " + topic : ""} 🎯`);
    }
  }

  function updateFocusDisplay() {
    const mins = Math.floor(focusSecondsLeft / 60);
    const secs = focusSecondsLeft % 60;
    document.getElementById("cmdFocusTimer").textContent =
      `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;

    const pct = (focusSecondsLeft / focusTotalSeconds) * 100;
    document.getElementById("cmdFocusBar").style.width = pct + "%";
  }

  function toggleFocusPause() {
    const btn = document.getElementById("cmdFocusPauseBtn");
    if (focusInterval) {
      clearInterval(focusInterval);
      focusInterval = null;
      btn.textContent = "▶ Resume";
    } else {
      focusInterval = setInterval(() => {
        focusSecondsLeft--;
        updateFocusDisplay();
        if (focusSecondsLeft <= 0) completeFocusSession();
      }, 1000);
      btn.textContent = "⏸ Pause";
    }
  }

  function completeFocusSession() {
    clearInterval(focusInterval);
    focusInterval = null;

    const minutesStudied = Math.round(focusTotalSeconds / 60);
    const hoursStudied = +(minutesStudied / 60).toFixed(2);

    // Auto-log to today's tracker
    const state = window.state;
    const td = getTodayDay();
    if (state && td) {
      const existing = state.days[td] || {};
      const oldHours = existing.hours || 0;
      const newHours = +(oldHours + hoursStudied).toFixed(2);

      state.days[td] = {
        ...existing,
        hours: newHours,
        topics: focusTopic && focusTopic !== "Deep Work"
          ? (existing.topics ? existing.topics + ", " + focusTopic : focusTopic)
          : existing.topics || "",
      };

      if (typeof window.addXP === "function") {
        window.addXP(Math.round(hoursStudied * 30), "Focus Session");
      }
      safeCall("saveState");
      safeCall("buildDailyTable");
      safeCall("updateOverview");
    }

    // Close overlay
    document.getElementById("cmdFocusOverlay").classList.remove("cmd-active");

    // Beep
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.frequency.value = 800;
      gain.gain.value = 0.3;
      osc.start();
      osc.stop(ctx.currentTime + 0.3);
    } catch (e) { /* silent fail */ }

    if (typeof window.showToast === "function") {
      window.showToast(
        `Focus done! ${minutesStudied}min logged (${hoursStudied}h) ✅`
      );
    }

    // Telegram notification
    if (typeof window.sendTelegramMsg === "function") {
      window.sendTelegramMsg(
        `🎯 *Focus Session Complete!*\n⏱ Duration: ${minutesStudied} min\n📚 Topic: ${focusTopic}\n✅ Auto-logged: ${hoursStudied}h`
      );
    }
  }

  function endFocusSession() {
    const elapsed = focusTotalSeconds - focusSecondsLeft;
    if (elapsed > 60) {
      // Log partial session (more than 1 minute)
      focusTotalSeconds = elapsed;
      completeFocusSession();
    } else {
      clearInterval(focusInterval);
      focusInterval = null;
      document.getElementById("cmdFocusOverlay").classList.remove("cmd-active");
      if (typeof window.showToast === "function") {
        window.showToast("Session ended (too short to log)");
      }
    }
  }

  // ─── VOICE INPUT ───────────────────────────────
  let useCapacitorSpeech = false;

  function initVoice() {
    if (window.CapacitorSpeechRecognition && window.Capacitor?.isNativePlatform?.()) {
      useCapacitorSpeech = true;
      return;
    }

    const SpeechRecognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      // Hide voice button if not supported
      const btn = document.getElementById("cmdVoiceBtn");
      if (btn) btn.style.display = "none";
      return;
    }

    recognition = new SpeechRecognition();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event) => {
      const transcript = event.results[0][0].transcript;
      document.getElementById("cmdInput").value = transcript;
      stopVoice();
      // Auto-execute after a brief delay for visual feedback
      setTimeout(() => executeCommand(transcript), 300);
    };

    recognition.onerror = () => {
      stopVoice();
      if (typeof window.showToast === "function") {
        window.showToast("Voice input failed. Try again. 🎙️");
      }
    };

    recognition.onend = () => {
      stopVoice();
    };
  }

  function toggleVoice() {
    if (isListening) {
      stopVoice();
    } else {
      startVoice();
    }
  }

  async function startVoice() {
    isListening = true;
    const btn = document.getElementById("cmdVoiceBtn");
    if (btn) {
      btn.classList.add("cmd-listening");
      btn.textContent = "🔴";
    }

    if (useCapacitorSpeech) {
      try {
        await window.CapacitorSpeechRecognition.requestPermissions();
        const result = await window.CapacitorSpeechRecognition.start({
          language: "en-US",
          maxResults: 1,
          prompt: "Say a command...",
          partialResults: false,
          popup: true
        });
        
        if (result && result.matches && result.matches.length > 0) {
          const transcript = result.matches[0];
          document.getElementById("cmdInput").value = transcript;
          stopVoice();
          setTimeout(() => executeCommand(transcript), 300);
        } else {
          stopVoice();
        }
      } catch (e) {
        stopVoice();
        console.error("Mic failed", e);
        if (typeof window.showToast === "function") window.showToast("Voice input failed: " + e.message + " 🎙️");
      }
      return;
    }

    if (!recognition) return;
    try {
      recognition.start();
    } catch (e) {
      stopVoice();
    }
  }

  async function stopVoice() {
    isListening = false;
    const btn = document.getElementById("cmdVoiceBtn");
    if (btn) {
      btn.classList.remove("cmd-listening");
      btn.textContent = "🎙️";
    }
    
    if (useCapacitorSpeech) {
      try { await window.CapacitorSpeechRecognition.stop(); } catch(e) {}
      return;
    }

    try {
      if (recognition) recognition.stop();
    } catch (e) { /* already stopped */ }
  }

  // ─── HELPERS ───────────────────────────────────
  function getTodayDay() {
    if (typeof window.getTodayDayNum === "function") {
      return window.getTodayDayNum();
    }
    // Fallback: compute locally
    const startDate = window.START_DATE;
    if (!startDate) return null;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const start = new Date(startDate);
    start.setHours(0, 0, 0, 0);
    const diff = Math.floor((today - start) / 86400000) + 1;
    const total = window.TOTAL_DAYS || 55;
    return diff < 1 || diff > total ? null : diff;
  }

  function getCurrentPhase(dayNum) {
    const phases = window.PHASES || window.state?.phasesList;
    if (!phases || !dayNum) return "Current Phase";
    const phase = phases.find((p) => dayNum >= p.dayStart && dayNum <= p.dayEnd);
    return phase ? phase.name : "Current Phase";
  }

  function calcCurrentStreak() {
    const state = window.state;
    if (!state) return 0;
    const td = getTodayDay();
    if (!td) return 0;

    let streak = 0;
    for (let d = td; d >= 1; d--) {
      const e = state.days[d] || {};
      if (e.completed || parseFloat(e.hours || 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  function calcBestStreak() {
    const state = window.state;
    if (!state) return 0;
    const totalDays = window.TOTAL_DAYS || 55;

    let best = 0,
      temp = 0;
    for (let d = 1; d <= totalDays; d++) {
      const e = state.days[d] || {};
      if (e.completed || parseFloat(e.hours || 0) > 0) {
        temp++;
        if (temp > best) best = temp;
      } else {
        temp = 0;
      }
    }
    return best;
  }

  function safeCall(fnName) {
    if (typeof window[fnName] === "function") {
      window[fnName]();
    }
  }

  function showResult(el, icon, title, desc) {
    el.innerHTML += `
      <div class="cmd-result">
        <span class="cmd-result-icon">${icon}</span>
        <div class="cmd-result-body">
          <div class="cmd-result-title">${title}</div>
          <div class="cmd-result-desc">${desc}</div>
        </div>
      </div>
    `;
  }

  function showLoading(el, text) {
    el.innerHTML = `
      <div class="cmd-loading">
        <div class="cmd-loading-dots">
          <span></span><span></span><span></span>
        </div>
        ${text}
      </div>
    `;
  }

  // ─── BOOTSTRAP ─────────────────────────────────
  // Wait for DOM + existing app to be ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => setTimeout(init, 500));
  } else {
    setTimeout(init, 500);
  }
})();
