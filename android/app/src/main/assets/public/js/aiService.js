/* ═══════════════════════════════════════════════════════════════
   AI SERVICE LAYER — Centralized Provider Switch
   TomCodex Academy · aiService.js
   ═══════════════════════════════════════════════════════════════

   Architecture:
     window.AI.generate(prompt)            → one-shot text generation
     window.AI.chat(systemPrompt, msgs)    → multi-turn conversation
     window.AI.setProvider(name)           → switch provider
     window.AI.getProvider()               → current provider name
     window.AI.setApiKey(key)              → store API key
     window.AI.getProviders()              → list all providers

   Providers:
     ✅ huggingface  — FREE (default), needs free token
     ✅ pollinations — FREE fallback, no key needed
     ⬚ cloudrun     — Future backend proxy for paid APIs

   ═══════════════════════════════════════════════════════════════ */

(function () {
  "use strict";

  // ─── PROVIDER DEFINITIONS ──────────────────────
  const PROVIDERS = {
    huggingface: {
      name: "Hugging Face",
      icon: "🤗",
      model: "mistralai/Mistral-7B-Instruct-v0.3",
      requiresKey: true,
      free: true,
      description: "Free tier: ~1000 req/day. High quality Mistral-7B model."
    },
    pollinations: {
      name: "Pollinations",
      icon: "🌸",
      model: "openai",
      requiresKey: false,
      free: true,
      description: "Free, no API key needed. Uses OpenAI-compatible endpoint."
    },
    cloudrun: {
      name: "Cloud Run Backend",
      icon: "☁️",
      model: "claude/openai",
      requiresKey: true,
      free: false,
      description: "Your own backend proxy — for Claude, OpenAI, etc. (Future)"
    }
  };

  // ─── STORAGE KEYS ─────────────────────────────
  const STORAGE_PROVIDER = "tomcodex_ai_provider";
  const STORAGE_API_KEY  = "tomcodex_ai_key";
  const STORAGE_HF_MODEL = "tomcodex_hf_model";
  const STORAGE_CLOUDRUN_URL = "tomcodex_cloudrun_url";

  // ─── STATE ────────────────────────────────────
  let currentProvider = localStorage.getItem(STORAGE_PROVIDER) || "huggingface";
  let apiKey = localStorage.getItem(STORAGE_API_KEY) || "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";
  let hfModel = localStorage.getItem(STORAGE_HF_MODEL) || PROVIDERS.huggingface.model;
  let cloudRunUrl = localStorage.getItem(STORAGE_CLOUDRUN_URL) || "";

  // ─── HUGGING FACE ADAPTER ─────────────────────
  async function hfGenerate(prompt, systemPrompt) {
    if (!apiKey) {
      console.warn("[AI] No Hugging Face token set. Falling back to Pollinations.");
      return pollinationsGenerate(prompt, systemPrompt);
    }

    const fullPrompt = systemPrompt
      ? `<s>[INST] ${systemPrompt}\n\n${prompt} [/INST]`
      : `<s>[INST] ${prompt} [/INST]`;

    try {
      const res = await fetch(
        `https://api-inference.huggingface.co/models/${hfModel}`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            inputs: fullPrompt,
            parameters: {
              max_new_tokens: 1024,
              temperature: 0.7,
              top_p: 0.9,
              return_full_text: false
            }
          })
        }
      );

      if (res.status === 503) {
        // Model is loading — wait and retry once
        const body = await res.json();
        const waitTime = (body.estimated_time || 20) * 1000;
        console.log(`[AI] HF model loading, retrying in ${waitTime / 1000}s...`);
        await new Promise((r) => setTimeout(r, Math.min(waitTime, 30000)));
        return hfGenerate(prompt, systemPrompt); // Retry once
      }

      if (!res.ok) {
        const err = await res.text();
        console.error(`[AI] HF API error ${res.status}:`, err);
        throw new Error(`HF API ${res.status}`);
      }

      const data = await res.json();

      // HF returns array of objects with generated_text
      if (Array.isArray(data) && data[0]?.generated_text) {
        return data[0].generated_text.trim();
      }
      // Some models return a single object
      if (data.generated_text) {
        return data.generated_text.trim();
      }
      // Fallback: stringify
      return typeof data === "string" ? data.trim() : JSON.stringify(data);

    } catch (err) {
      console.error("[AI] Hugging Face failed, falling back to Pollinations:", err);
      return pollinationsGenerate(prompt, systemPrompt);
    }
  }

  async function hfChat(systemPrompt, messages) {
    // Convert message history into a single prompt for instruct models
    const conversationText = messages
      .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
      .join("\n");

    return hfGenerate(conversationText, systemPrompt);
  }

  // ─── POLLINATIONS ADAPTER (FALLBACK) ──────────
  async function pollinationsGenerate(prompt, systemPrompt) {
    let url;
    if (systemPrompt) {
      const systemParam = encodeURIComponent(systemPrompt);
      const promptParam = encodeURIComponent(prompt);
      url = `https://text.pollinations.ai/${promptParam}?system=${systemParam}&model=openai`;
    } else {
      url = `https://text.pollinations.ai/${encodeURIComponent(prompt)}?model=openai`;
    }

    const res = await fetch(url);
    if (!res.ok) throw new Error(`Pollinations HTTP ${res.status}`);
    const text = await res.text();
    return text?.trim() || "";
  }

  async function pollinationsChat(systemPrompt, messages) {
    const conversationText = messages
      .map((m) => `${m.role.toUpperCase()}: ${m.content}`)
      .join("\n");

    const systemParam = encodeURIComponent(systemPrompt);
    const promptParam = encodeURIComponent(conversationText);
    const url = `https://text.pollinations.ai/${promptParam}?system=${systemParam}&model=openai`;

    const res = await fetch(url);
    if (!res.ok) throw new Error(`Pollinations HTTP ${res.status}`);
    const text = await res.text();
    return text?.trim() || "";
  }

  // ─── CLOUD RUN ADAPTER (FUTURE) ───────────────
  async function cloudRunGenerate(prompt, systemPrompt) {
    if (!cloudRunUrl || !apiKey) {
      console.warn("[AI] Cloud Run not configured. Falling back to Pollinations.");
      return pollinationsGenerate(prompt, systemPrompt);
    }

    try {
      const res = await fetch(`${cloudRunUrl}/api/ai/generate`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ prompt, systemPrompt })
      });

      if (!res.ok) throw new Error(`Cloud Run ${res.status}`);
      const data = await res.json();
      return data.text || data.response || "";
    } catch (err) {
      console.error("[AI] Cloud Run failed, falling back:", err);
      return pollinationsGenerate(prompt, systemPrompt);
    }
  }

  async function cloudRunChat(systemPrompt, messages) {
    if (!cloudRunUrl || !apiKey) {
      return pollinationsChat(systemPrompt, messages);
    }

    try {
      const res = await fetch(`${cloudRunUrl}/api/ai/chat`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ systemPrompt, messages })
      });

      if (!res.ok) throw new Error(`Cloud Run ${res.status}`);
      const data = await res.json();
      return data.text || data.response || "";
    } catch (err) {
      console.error("[AI] Cloud Run chat failed, falling back:", err);
      return pollinationsChat(systemPrompt, messages);
    }
  }

  // ─── ROUTER ───────────────────────────────────
  function getAdapter() {
    switch (currentProvider) {
      case "huggingface":
        return { generate: hfGenerate, chat: hfChat };
      case "pollinations":
        return { generate: pollinationsGenerate, chat: pollinationsChat };
      case "cloudrun":
        return { generate: cloudRunGenerate, chat: cloudRunChat };
      default:
        return { generate: pollinationsGenerate, chat: pollinationsChat };
    }
  }

  // ─── PUBLIC API ───────────────────────────────
  window.AI = {
    /**
     * One-shot text generation.
     * @param {string} prompt - The prompt/question
     * @param {string} [systemPrompt] - Optional system context
     * @returns {Promise<string>} Generated text
     */
    async generate(prompt, systemPrompt) {
      const adapter = getAdapter();
      return adapter.generate(prompt, systemPrompt || "");
    },

    /**
     * Multi-turn chat.
     * @param {string} systemPrompt - System instructions
     * @param {Array<{role:string, content:string}>} messages - Conversation history
     * @returns {Promise<string>} AI response text
     */
    async chat(systemPrompt, messages) {
      const adapter = getAdapter();
      return adapter.chat(systemPrompt, messages);
    },

    /** Switch active provider */
    setProvider(name) {
      if (!PROVIDERS[name]) {
        console.error(`[AI] Unknown provider: ${name}`);
        return;
      }
      currentProvider = name;
      localStorage.setItem(STORAGE_PROVIDER, name);
      console.log(`[AI] Switched to ${PROVIDERS[name].name} ${PROVIDERS[name].icon}`);
      // Dispatch event so settings UI can react
      window.dispatchEvent(new CustomEvent("ai-provider-changed", { detail: { provider: name } }));
    },

    /** Get current provider name */
    getProvider() {
      return currentProvider;
    },

    /** Get provider display info */
    getProviderInfo() {
      return PROVIDERS[currentProvider] || PROVIDERS.pollinations;
    },

    /** Get all available providers */
    getProviders() {
      return { ...PROVIDERS };
    },

    /** Store API key */
    setApiKey(key) {
      apiKey = key;
      localStorage.setItem(STORAGE_API_KEY, key);
      console.log("[AI] API key saved.");
    },

    /** Get stored API key (masked) */
    hasApiKey() {
      return !!apiKey;
    },

    /** Set Hugging Face model override */
    setModel(modelId) {
      hfModel = modelId;
      localStorage.setItem(STORAGE_HF_MODEL, modelId);
      console.log(`[AI] HF model set to: ${modelId}`);
    },

    /** Get current HF model */
    getModel() {
      return hfModel;
    },

    /** Set Cloud Run URL (future) */
    setCloudRunUrl(url) {
      cloudRunUrl = url;
      localStorage.setItem(STORAGE_CLOUDRUN_URL, url);
    },

    /** Quick health check */
    async test() {
      try {
        const start = performance.now();
        const result = await window.AI.generate("Say 'hello' in one word.");
        const elapsed = Math.round(performance.now() - start);
        console.log(`[AI] Test passed (${elapsed}ms): "${result.substring(0, 80)}..."`);
        return { success: true, provider: currentProvider, time: elapsed, response: result };
      } catch (err) {
        console.error("[AI] Test failed:", err);
        return { success: false, provider: currentProvider, error: err.message };
      }
    }
  };

  // ─── SETTINGS UI INITIALIZATION ───────────────
  function initAISettings() {
    const select = document.getElementById("aiProviderSelect");
    const keySection = document.getElementById("aiKeySection");
    const keyInput = document.getElementById("aiApiKeyInput");
    const saveKeyBtn = document.getElementById("aiSaveKeyBtn");
    const statusEl = document.getElementById("aiProviderStatus");
    const testBtn = document.getElementById("aiTestBtn");

    if (!select) return; // Settings UI not in DOM yet

    // Settings panel toggle
    const settingsToggle = document.getElementById("aiSettingsToggle");
    const settingsPanel = document.getElementById("aiSettingsPanel");
    settingsToggle?.addEventListener("click", () => {
      if (settingsPanel) {
        const isVisible = settingsPanel.style.display !== "none";
        settingsPanel.style.display = isVisible ? "none" : "block";
        settingsToggle.style.opacity = isVisible ? "0.8" : "1";
      }
    });

    // Set current values
    select.value = currentProvider;
    if (apiKey) {
      keyInput.value = "••••••••" + apiKey.slice(-4);
      keyInput.dataset.masked = "true";
    }
    updateKeyVisibility();

    // Provider change
    select.addEventListener("change", (e) => {
      window.AI.setProvider(e.target.value);
      updateKeyVisibility();
      updateStatus();
    });

    // Clear masked password on focus
    keyInput?.addEventListener("focus", () => {
      if (keyInput.dataset.masked === "true") {
        keyInput.value = "";
        keyInput.dataset.masked = "false";
      }
    });

    // Save key
    saveKeyBtn?.addEventListener("click", () => {
      const key = keyInput.value.trim();
      if (!key || key.startsWith("••••")) return;
      window.AI.setApiKey(key);
      keyInput.value = "••••••••" + key.slice(-4);
      keyInput.dataset.masked = "true";
      updateStatus("Key saved! ✅");
    });

    // Test button
    testBtn?.addEventListener("click", async () => {
      testBtn.textContent = "Testing...";
      testBtn.disabled = true;
      const result = await window.AI.test();
      testBtn.textContent = "🧪 Test AI";
      testBtn.disabled = false;
      if (result.success) {
        updateStatus(`✅ Working! (${result.time}ms)`);
      } else {
        updateStatus(`❌ Failed: ${result.error}`);
      }
    });

    function updateKeyVisibility() {
      const info = PROVIDERS[window.AI.getProvider()];
      if (keySection) {
        keySection.style.display = info?.requiresKey ? "flex" : "none";
      }
    }

    function updateStatus(msg) {
      if (!statusEl) return;
      const info = window.AI.getProviderInfo();
      statusEl.innerHTML = msg || `${info.icon} ${info.name} — ${info.description}`;
    }

    updateStatus();
  }

  // Listen for provider changes from other parts of the app
  window.addEventListener("ai-provider-changed", () => {
    const select = document.getElementById("aiProviderSelect");
    if (select) select.value = currentProvider;
  });

  // Initialize settings UI when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAISettings);
  } else {
    initAISettings();
  }

  console.log(`[AI] Service loaded — Provider: ${PROVIDERS[currentProvider]?.name || currentProvider} ${PROVIDERS[currentProvider]?.icon || ""}`);
})();
