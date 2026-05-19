/**
 * PES_ENGINE — Personal Execution System Plugin
 * Integrates with TomCodex Academy app.js
 */

const PES_ENGINE = (function() {
  const CORE_API = "https://text.pollinations.ai/";
  const STORAGE_KEY_PLAN = "pes_daily_plan_";
  
  let currentTask = null;
  let focusTimeLeft = 0;
  let focusInterval = null;

  // --- INITIALIZATION ---
  function init() {
    console.log("PES Engine: Initializing...");
    
    // 1. Inject UI Components (if not in HTML)
    injectPESUI();
    
    // 2. Setup Event Listeners
    setupListeners();
    
    // 3. Load/Generate Daily Plan
    setTimeout(() => {
      if (window.state) {
        checkDailyPlan();
        checkNightReview();
      } else {
        // Retry if state isn't ready
        setTimeout(init, 500);
      }
    }, 1000);
  }

  function injectPESUI() {
    // Start My Day FAB
    if (!document.getElementById("pesSmdFab")) {
      const fab = document.createElement("button");
      fab.id = "pesSmdFab";
      fab.className = "pes-smd-fab";
      fab.innerHTML = '<span class="pes-smd-icon">🌅</span>';
      fab.title = "Start My Day";
      document.body.appendChild(fab);
    }

    // Focus Overlay
    if (!document.getElementById("pesFocusOverlay")) {
      const overlay = document.createElement("div");
      overlay.id = "pesFocusOverlay";
      overlay.className = "pes-focus-overlay";
      overlay.style.display = "none";
      overlay.innerHTML = `
        <div class="pes-focus-timer" id="pesFocusTimer">25:00</div>
        <div class="pes-focus-task" id="pesFocusTask">Deep Work Session</div>
        <div class="pes-focus-actions">
          <button class="pes-focus-btn" id="pesEndFocus">End Early</button>
          <button class="pes-focus-btn primary" id="pesCompleteFocus">Complete & Log</button>
        </div>
      `;
      document.body.appendChild(overlay);
    }
  }

  function setupListeners() {
    document.getElementById("pesSmdFab")?.addEventListener("click", () => {
      openStartMyDay();
    });

    document.getElementById("pesCompleteFocus")?.addEventListener("click", () => {
      completeFocusSession();
    });

    document.getElementById("pesEndFocus")?.addEventListener("click", () => {
      if (confirm("End session early? Hours won't be logged.")) {
        hideFocusMode();
      }
    });

    // Keyboard shortcut F2 for Focus Mode
    window.addEventListener("keydown", (e) => {
      if (e.key === "f2" || e.key === "F2") {
        startFocusMode("Quick Focus", 25);
      }
    });
  }

  // --- FEATURE 1: START MY DAY ---
  async function checkDailyPlan() {
    const todayStr = new Date().toISOString().split('T')[0];
    const cached = localStorage.getItem(STORAGE_KEY_PLAN + todayStr);
    
    if (cached) {
      displayPlanCard(JSON.parse(cached));
    } else {
      generateDailyPlan();
    }
  }

  async function generateDailyPlan() {
    if (!window.state) return;
    
    const dayNum = window.getTodayDayNum() || "General";
    const phase = window.getPhaseForDay(dayNum)?.name || "Learning";
    const todos = window.state.todos ? window.state.todos.filter(t => !t.done).map(t => t.text).slice(0, 3) : [];
    
    const prompt = `Generate a 4-step daily study plan for a Salesforce learner. 
      Context: Day ${dayNum}, Phase: ${phase}. Pending tasks: ${todos.join(", ")}. 
      Return only JSON format: [{"slot":"Morning","task":"...","duration":45,"reason":"..."}]`;
    
    try {
      const resp = await fetch(`${CORE_API}${encodeURIComponent(prompt)}?model=openai&cache=true`);
      const text = await resp.text();
      // Clean potential markdown ticks
      const cleanJson = text.replace(/```json|```/g, "").trim();
      const plan = JSON.parse(cleanJson);
      
      const todayStr = new Date().toISOString().split('T')[0];
      localStorage.setItem(STORAGE_KEY_PLAN + todayStr, JSON.stringify(plan));
      displayPlanCard(plan);
    } catch (e) {
      console.warn("PES: Failed to generate plan", e);
    }
  }

  function displayPlanCard(plan) {
    const overview = document.getElementById("overview");
    if (!overview) return;
    
    let card = document.getElementById("pesPlanCard");
    if (!card) {
      card = document.createElement("div");
      card.id = "pesPlanCard";
      card.className = "pes-plan-card";
      overview.prepend(card);
    }
    
    const itemsHtml = plan.map(item => `
      <div class="pes-plan-item" onclick="PES_ENGINE.startFocusMode('${item.task}', ${item.duration})">
        <div style="font-size:10px; color:var(--pes-blue); margin-bottom:4px;">${item.slot} (${item.duration}m)</div>
        <div style="font-weight:600; font-size:13px; margin-bottom:4px;">${item.task}</div>
        <div style="font-size:11px; color:rgba(255,255,255,0.5);">${item.reason}</div>
      </div>
    `).join("");
    
    card.innerHTML = `
      <div class="pes-plan-header">
        <span class="pes-plan-title">🎯 AI Daily Strategy</span>
        <button onclick="this.parentElement.parentElement.remove()" style="background:none;border:none;color:white;cursor:pointer;opacity:0.5;">✕</button>
      </div>
      <div class="pes-plan-grid">${itemsHtml}</div>
    `;
  }

  // --- FEATURE 2: FOCUS MODE ---
  function startFocusMode(task, minutes) {
    currentTask = task;
    focusTimeLeft = minutes * 60;
    
    const overlay = document.getElementById("pesFocusOverlay");
    overlay.style.display = "flex";
    document.getElementById("pesFocusTask").textContent = task;
    
    updateTimerDisplay();
    
    if (focusInterval) clearInterval(focusInterval);
    focusInterval = setInterval(() => {
      focusTimeLeft--;
      updateTimerDisplay();
      if (focusTimeLeft <= 0) {
        clearInterval(focusInterval);
        alert("Session Complete! Don't forget to log it.");
      }
    }, 1000);
  }

  function updateTimerDisplay() {
    const m = Math.floor(focusTimeLeft / 60);
    const s = focusTimeLeft % 60;
    const display = `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    document.getElementById("pesFocusTimer").textContent = display;
    document.title = `(${display}) ${currentTask} | TomCodex`;
  }

  function hideFocusMode() {
    const overlay = document.getElementById("pesFocusOverlay");
    overlay.style.display = "none";
    if (focusInterval) clearInterval(focusInterval);
    document.title = "TomCodex Academy";
  }

  async function completeFocusSession() {
    const hours = Number((( (focusTimeLeft > 0 ? ( (currentTask === "Quick Focus" ? 25*60 : focusTimeLeft) ) : (focusTimeLeft)) ) / 3600).toFixed(2));
    // Calculate actual elapsed time if ended early but "completed"
    // For simplicity, we'll log the full planned duration if they hit complete.
    const durationMin = 25; // Default or from task
    const hoursToLog = Number((durationMin / 60).toFixed(1));
    
    const today = window.getTodayDayNum();
    if (today && window.state.days) {
      if (!window.state.days[today]) {
        window.state.days[today] = { hours: 0, topics: "", pomodoros: 0, status: "partial" };
      }
      window.state.days[today].hours += hoursToLog;
      window.state.days[today].pomodoros += 1;
      window.state.days[today].topics += (window.state.days[today].topics ? ", " : "") + currentTask;
      
      if (window.addXP) window.addXP(50 + (hoursToLog * 10), "Deep Work Completion");
      await window.saveState();
      if (window.updateOverview) window.updateOverview();
      if (window.buildDailyTable) window.buildDailyTable();
    }
    
    hideFocusMode();
    showToast(`Great work! ${hoursToLog}h logged to Day ${today}. 🚀`);
  }

  // --- FEATURE 3: NIGHT REVIEW ---
  function checkNightReview() {
    const now = new Date();
    if (now.getHours() >= 20) { // 8 PM
      const overview = document.getElementById("overview");
      if (!overview || document.getElementById("pesNightCard")) return;
      
      const card = document.createElement("div");
      card.id = "pesNightCard";
      card.className = "pes-night-card";
      card.innerHTML = `
        <h3 style="margin:0; font-size:18px;">🌙 Daily Reflection</h3>
        <p class="pes-night-quote" id="pesNightReflect">Generation reflection...</p>
        <button onclick="this.parentElement.remove()" class="pes-focus-btn" style="margin-top:15px; font-size:12px;">Close for tonight</button>
      `;
      overview.appendChild(card);
      generateNightReflection();
    }
  }

  async function generateNightReflection() {
    const day = window.getTodayDayNum();
    const hours = window.state.days[day]?.hours || 0;
    const prompt = `Generate a 1-sentence motivational reflection for a student who studied ${hours} hours today on Salesforce Day ${day}. Mentor tone.`;
    
    try {
      const resp = await fetch(`${CORE_API}${encodeURIComponent(prompt)}?model=openai`);
      const text = await resp.text();
      document.getElementById("pesNightReflect").textContent = text.replace(/"/g, "");
    } catch (e) {}
  }

  function openStartMyDay() {
    // For now, scrolls to Overview or re-triggers plan
    const ov = document.getElementById("overview");
    if (ov) {
       ov.scrollIntoView({ behavior: 'smooth' });
       window.showToast("Greeting! Check your AI strategy at the top.");
    }
  }

  return {
    init,
    startFocusMode
  };
})();

// Start the engine
PES_ENGINE.init();
window.PES_ENGINE = PES_ENGINE;
