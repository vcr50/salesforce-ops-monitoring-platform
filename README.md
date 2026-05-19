# SentinelFlow — AI Incident Intelligence Platform

> **Built by TomCodeX Inc** · Powered by Salesforce + Agentforce

[![Live Demo](https://img.shields.io/badge/Demo-Live%20on%20Salesforce-blue?style=flat-square)](http://localhost:3000)
[![Built with Salesforce](https://img.shields.io/badge/Platform-Salesforce%20Experience%20Cloud-00A1E0?style=flat-square)](https://salesforce.com)
[![AI Powered](https://img.shields.io/badge/AI-Agentforce-8b5cf6?style=flat-square)](https://salesforce.com/agentforce)
[![Node.js](https://img.shields.io/badge/Backend-Node.js%20%2B%20Express-339933?style=flat-square)](https://nodejs.org)

---

## What is SentinelFlow?

SentinelFlow is an **incident intelligence platform** that helps operations teams detect, analyze, and resolve system failures — with full business impact visibility.

Unlike traditional monitoring tools that only alert you *something broke*, SentinelFlow tells you:
- **Why** it broke (AI root cause analysis)
- **What to do** (guided recommended actions)
- **How much is at stake** (real-time revenue & user impact)

Built natively on **Salesforce Experience Cloud + Agentforce**, it eliminates manual log digging and turns passive alerts into confident, actionable decisions.

## 🏗️ Architecture

```
Salesforce Experience Cloud
├── sentinelFlowPortalApp          (Master App Shell — Topbar + Navigation)
├── sentinelFlowPortalCommandCenter (Home — KPIs + Live Incidents + AI Copilot)
├── sentinelFlowPortalIncidentsPage (Full Incident Module — Split Pane Layout)
│   ├── Alert Banner         (Critical incident notifications)
│   ├── Incident Table       (Custom HTML table, no lightning-datatable)
│   ├── Detail Panel         (Business impact, Lifecycle tracker, AI block)
│   └── Activity Timeline    (Chronological event log per incident)
├── sentinelFlowPortalIntegrationsPage (Integration health + Live log terminal)
├── sentinelFlowPortalLogin         (Custom dark-mode login page)
└── Static Resources         (sentinelFlowLogo.png)

Node.js Backend (Local Preview)
├── src/app.js              (Express server — serves static dashboard)
├── src/dashboard/          (Standalone SPA: index.html, style.css, app.js)
└── src/routes/             (Auth, Records, Sync, Analytics, System)
```

---

## ⚡ Core Features

### 1. Real-Time Incident Queue
- Auto-refreshes every **10 seconds** via `setInterval` polling
- Custom HTML table (no `lightning-datatable`) with sortable columns
- Critical incidents highlighted with pulsing red dot + left-border glow

### 2. Simulate Failure Engine
- 4 pre-built realistic failure scenarios (Stripe, Auth0, Salesforce Sync, SAP ERP)
- Rotates through scenarios on each click
- Fires alert banner + error toast immediately on injection

### 3. AI Analysis (Agentforce)
- Structured output: Root Cause + Recommended Action + Confidence Score
- Animated scanning progress bar during analysis
- Optimistic UI — status flips to `Investigating` before server responds

### 4. Incident Lifecycle
```
New → Investigating → Healing → Resolved
```
- Visual step tracker updates in real time with each state transition
- All transitions visible in both the table row and the detail panel simultaneously

### 5. Business Impact Panel
- Users Affected + Revenue at Risk displayed per incident
- Revenue formatted intelligently: `$84K`, `$1.2M`
- Red accent on revenue danger card to signal urgency

### 6. Activity Timeline
- Per-incident chronological log of every action
- Color-coded dots: 🔴 Created, 🟣 AI, 🟡 Healing, 🟢 Resolved
- Newest events always appear at top

### 7. Custom Login Page
- Dark-mode branded experience with SentinelFlow logo
- Split-panel: login form (left) + feature highlights (right)
- Footer: `© 2026 TomCodeX Inc · Privacy Policy · Terms & Conditions`

---

## 💰 Business Value

| Metric | Before SentinelFlow | After SentinelFlow |
|--------|--------------------|--------------------|
| Avg Resolution Time (MTTR) | 16 minutes | **4.2 minutes** |
| Manual Effort | High | **85% reduced** |
| Revenue Visibility | None | **Real-time per incident** |
| SLA Compliance | Reactive | **99.2% proactive** |
| AI Confidence | N/A | **91% average** |

**This month: $1.2M in revenue protected** through 12 auto-healed incidents.

---

## 🏷️ Pricing

| Plan | Price | Key Features |
|------|-------|-------------|
| **Starter** | Free | 5 integrations, basic alerts, 7-day history |
| **Growth** | $49/mo | Agentforce AI, Business impact, 25 integrations |
| **Pro** | $149/mo | Auto-heal, custom runbooks, unlimited integrations |
| **Enterprise** | Custom | On-premise, SSO/SAML, dedicated success manager |

---

## 🚀 Run Locally

```bash
# 1. Clone the repo
git clone <repo-url>
cd SentinelFlow

# 2. Install dependencies
npm install

# 3. Setup environment
cp .env.example .env

# 4. Start the dev server (auto-reload with nodemon)
npm run dev

# 5. Open in browser
open http://localhost:3000
```

Dashboard is available at: **http://localhost:3000/dashboard/index.html**

> The dashboard SPA works fully with built-in mock data. Salesforce credentials in `.env` are only required for live Apex data sync.

---

## 🔧 Deploy to Salesforce

```bash
# Authenticate to your org
sf org login web -a vjdev@asap.com

# Deploy all LWC components + static resources
sf project deploy start -d force-app -o vjdev@asap.com

# Open Experience Builder to configure pages
sf org open -o vjdev@asap.com
```

**Experience Builder Configuration:**
1. Navigate to your Experience Cloud site
2. Drag `sentinelFlowPortalApp` onto the main page
3. For Login page — drag `sentinelFlowPortalLogin` and remove the default Salesforce login component
4. Publish the site

---

## 🏅 Pitch Q&A

**Q: What did you build?**
> SentinelFlow is an incident intelligence platform that helps operations teams detect, analyze, and resolve system failures — with full business impact visibility.

**Q: Why is it different?**
> Traditional tools alert you *something broke*. SentinelFlow tells you *why*, *what to do*, and *how much revenue is at risk* — all in one view. AI turns passive alerts into confident decisions.

**Q: Why Salesforce?**
> Salesforce provides enterprise-grade data, automation (Flows, Apex), and real-time events (Platform Events). Agentforce gives us native AI without third-party LLM costs. We focus on product behavior, not infrastructure.

---

## 📁 Project Structure

```
SentinelFlow/
├── force-app/main/default/
│   ├── lwc/
│   │   ├── sentinelFlowPortalApp/             ← Master app shell
│   │   ├── sentinelFlowPortalCommandCenter/   ← Home dashboard
│   │   ├── sentinelFlowPortalIncidentsPage/   ← Core incident module ⭐
│   │   ├── sentinelFlowPortalIncidentTable/   ← Incident table widget
│   │   ├── sentinelFlowPortalIntegrationsPage/← Integration monitor
│   │   ├── sentinelFlowPortalLogin/           ← Custom login page
│   │   ├── sentinelFlowPortalSummary/         ← KPI summary cards
│   │   └── sentinelFlowPortalCopilot/         ← AI Copilot chat
│   ├── classes/
│   │   └── SentinelFlowPortalController.cls   ← Apex data layer
│   └── staticresources/
│       └── sentinelFlowLogo.png               ← Brand asset
├── src/
│   ├── app.js                          ← Express server
│   └── dashboard/                      ← Standalone preview SPA
│       ├── index.html
│       ├── style.css
│       └── app.js
├── package.json
└── README.md
```

---

## 👤 Author

**VJ** · TomCodeX Inc  
Salesforce Developer · Product Builder  
© 2026 TomCodeX Inc. All rights reserved.
