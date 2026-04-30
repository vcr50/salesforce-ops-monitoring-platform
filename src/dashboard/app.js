'use strict';
// ── DATA ──────────────────────────────────────────────────────────────────────
const INCIDENTS = [
  {id:'INC-0041',desc:'API Gateway timeout — Payment Service',sev:'Critical',status:'Open',integration:'Payment API',env:'Production',affected:1240,sla:'Breached',time:'4m ago',rootCause:'Connection pool exhausted due to spike in transaction volume',action:'Restart Service',confidence:92,impact:'High'},
  {id:'INC-0040',desc:'Salesforce Apex CPU limit breach',sev:'Critical',status:'Investigating',integration:'SF Core',env:'Production',affected:580,sla:'At Risk',time:'11m ago',rootCause:'Recursive trigger loop detected on Opportunity object',action:'Escalate',confidence:87,impact:'High'},
  {id:'INC-0039',desc:'Order Management sync failure',sev:'High',status:'Healing',integration:'ERP Sync',env:'Production',affected:310,sla:'OK',time:'18m ago',rootCause:'Schema mismatch in v2.1 payload — field Order_Priority__c missing',action:'Retry',confidence:95,impact:'Medium'},
  {id:'INC-0038',desc:'Email delivery latency > 8s',sev:'Medium',status:'Open',integration:'SMTP Gateway',env:'Staging',affected:90,sla:'OK',time:'32m ago',rootCause:'MX record propagation delay after DNS change',action:'Retry',confidence:78,impact:'Low'},
  {id:'INC-0037',desc:'CRM data import partial failure',sev:'High',status:'Open',integration:'Data Loader',env:'Production',affected:430,sla:'At Risk',time:'45m ago',rootCause:'Malformed CSV — 34 rows failed validation on Phone field',action:'Escalate',confidence:91,impact:'Medium'},
  {id:'INC-0036',desc:'Webhook signature verification fail',sev:'Medium',status:'Investigating',integration:'Stripe Webhook',env:'Production',affected:55,sla:'OK',time:'1h ago',rootCause:'Secret key rotation not propagated to receiver endpoint',action:'Restart Service',confidence:83,impact:'Low'},
  {id:'INC-0035',desc:'Dashboard report timeout',sev:'Low',status:'Resolved',integration:'Reports API',env:'Sandbox',affected:12,sla:'OK',time:'2h ago',rootCause:'Missing index on Incident__c.CreatedDate causing full table scan',action:'Retry',confidence:98,impact:'Low'},
];

const INTEGRATIONS = [
  {name:'Payment API',status:'Failed',resp:'8,420ms',uptime:'94.2%',lastOk:'4m ago',errors:14,color:'#ef4444'},
  {name:'Salesforce Core',status:'Warning',resp:'1,230ms',uptime:'98.1%',lastOk:'2m ago',errors:3,color:'#f59e0b'},
  {name:'ERP Sync',status:'Warning',resp:'2,800ms',uptime:'97.4%',lastOk:'18m ago',errors:7,color:'#f59e0b'},
  {name:'SMTP Gateway',status:'Warning',resp:'4,100ms',uptime:'99.0%',lastOk:'1m ago',errors:2,color:'#f59e0b'},
  {name:'Stripe Webhook',status:'OK',resp:'210ms',uptime:'99.9%',lastOk:'0s ago',errors:0,color:'#10b981'},
  {name:'Data Loader',status:'OK',resp:'540ms',uptime:'99.5%',lastOk:'1m ago',errors:0,color:'#10b981'},
  {name:'Reports API',status:'OK',resp:'320ms',uptime:'99.8%',lastOk:'0s ago',errors:0,color:'#10b981'},
  {name:'Agentforce AI',status:'OK',resp:'180ms',uptime:'100%',lastOk:'0s ago',errors:0,color:'#10b981'},
  {name:'Platform Events',status:'OK',resp:'90ms',uptime:'100%',lastOk:'0s ago',errors:0,color:'#10b981'},
];

const LOGS = [
  {api:'Payment API',status:'Failed',resp:'8420ms',error:'Connection pool exhausted',ts:'04:12:33'},
  {api:'ERP Sync',status:'Failed',resp:'2800ms',error:'Schema mismatch v2.1',ts:'03:58:10'},
  {api:'SMTP Gateway',status:'Warning',resp:'4100ms',error:'Latency threshold exceeded',ts:'03:44:22'},
  {api:'Salesforce Core',status:'Warning',resp:'1230ms',error:'CPU limit 85% utilization',ts:'03:41:05'},
  {api:'Stripe Webhook',status:'Success',resp:'210ms',error:'—',ts:'03:38:44'},
  {api:'Reports API',status:'Success',resp:'320ms',error:'—',ts:'03:35:18'},
];

const AI_INSIGHTS = [
  {id:'INC-0041',title:'Payment API — Connection Pool Exhaustion',cause:'Traffic spike caused all 100 connections to be consumed. No circuit breaker configured.',action:'Restart Service',confidence:92,actionType:'restart'},
  {id:'INC-0040',title:'Apex CPU Limit — Recursive Trigger Loop',cause:'Trigger on Opportunity fires before_update and calls a Flow that re-saves the record.',action:'Escalate to Dev Team',confidence:87,actionType:'escalate'},
  {id:'INC-0039',title:'ERP Sync — Schema Field Missing',cause:'v2.1 payload schema removed Order_Priority__c. Receiver still expects it.',action:'Retry with v2.0 Schema',confidence:95,actionType:'retry'},
];

const IMPACT_DATA = [
  {id:'INC-0041',title:'Payment API Outage',users:1240,arpu:42,type:'Payment Integration',risk:'Critical'},
  {id:'INC-0040',title:'Apex CPU Breach',users:580,arpu:38,type:'Platform Health',risk:'High'},
  {id:'INC-0039',title:'ERP Sync Failure',users:310,arpu:25,type:'Data Integration',risk:'Medium'},
  {id:'INC-0037',title:'CRM Import Failure',users:430,arpu:30,type:'Data Import',risk:'High'},
];

// ── HELPERS ───────────────────────────────────────────────────────────────────
function sevClass(s){return{Critical:'sev-critical',High:'sev-high',Medium:'sev-medium',Low:'sev-low'}[s]||'sev-low';}
function statusClass(s){return{Open:'status-open',Investigating:'status-investigating',Resolved:'status-resolved',Healing:'status-healing'}[s]||'status-open';}
function fmtMoney(n){return n>=1000?`$${(n/1000).toFixed(0)}K`:`$${n}`;}
function riskClass(r){return{Critical:'risk-critical',High:'risk-high',Medium:'risk-medium',Low:'risk-low'}[r]||'risk-low';}
function actionClass(a){return{Retry:'',Escalate:'escalate','Restart Service':'restart'}[a]||'';}

// ── CLOCK ─────────────────────────────────────────────────────────────────────
function updateClock(){
  const n=new Date();
  const t=el('barTime');
  if(t)t.textContent=n.toLocaleTimeString('en-US',{hour12:false});
  const r=el('lastRefreshed');
  if(r)r.textContent=`Last refreshed at ${n.toLocaleTimeString()}`;
}
setInterval(updateClock,1000);updateClock();

function el(id){return document.getElementById(id);}

// ── NAVIGATION ────────────────────────────────────────────────────────────────
let currentPage='home';
function switchPage(page,navEl){
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  const target=el('page-'+page);
  if(target)target.classList.add('active');
  document.querySelectorAll('.nav-item').forEach(n=>n.classList.remove('active'));
  if(navEl)navEl.classList.add('active');
  else{const n=document.querySelector(`.nav-item[data-page="${page}"]`);if(n)n.classList.add('active');}
  document.querySelectorAll('.sidebar-item').forEach(s=>s.classList.remove('active'));
  const sb=el('sb-'+page);if(sb)sb.classList.add('active');
  currentPage=page;
  if(page==='incidents')renderFullIncidents(INCIDENTS);
  if(page==='integrations')renderIntegrations();
  if(page==='impact')renderImpact();
  if(page==='copilot')initCopilot();
  return false;
}

// ── HOME ──────────────────────────────────────────────────────────────────────
function renderHomeIncidents(data){
  const tbody=el('incidentTableBody');
  if(!tbody)return;
  tbody.innerHTML=data.map(i=>`
    <tr>
      <td><span style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--muted)">${i.id}</span></td>
      <td style="max-width:240px;white-space:normal">${i.desc}</td>
      <td><span class="sev-badge ${sevClass(i.sev)}">${i.sev}</span></td>
      <td><span class="status-chip ${statusClass(i.status)}">${i.status}</span></td>
      <td>${i.affected.toLocaleString()}</td>
      <td style="color:var(--muted);font-size:.72rem">${i.time}</td>
      <td><button class="action-btn" onclick='openDrawer(${JSON.stringify(i)})'>Analyze →</button></td>
    </tr>`).join('');
}

function filterIncidents(){
  const v=el('severityFilter').value;
  const filtered=v==='all'?INCIDENTS:INCIDENTS.filter(i=>i.sev===v);
  renderHomeIncidents(filtered);
}

function renderAIInsights(){
  const list=el('aiInsightsList');
  if(!list)return;
  list.innerHTML=AI_INSIGHTS.map(ins=>{
    const r=ins.confidence;
    const circ=2*Math.PI*14;
    const dash=circ*(r/100);
    return`<div class="ai-insight-card" onclick='openDrawer(${JSON.stringify(INCIDENTS.find(x=>x.id===ins.id)||{})})'>
      <div class="insight-header">
        <div class="insight-title">${ins.title}</div>
        <div class="confidence-ring">
          <svg width="36" height="36" viewBox="0 0 36 36">
            <circle cx="18" cy="18" r="14" fill="none" stroke="var(--border)" stroke-width="3"/>
            <circle cx="18" cy="18" r="14" fill="none" stroke="var(--accent)" stroke-width="3" stroke-dasharray="${dash} ${circ}" stroke-linecap="round"/>
          </svg>
          <div class="confidence-text">${r}%</div>
        </div>
      </div>
      <div class="insight-cause">${ins.cause}</div>
      <div class="insight-action">
        Recommended: <span class="action-pill ${actionClass(ins.action)}">${ins.action}</span>
      </div>
    </div>`;
  }).join('');
}

// ── DRAWER ────────────────────────────────────────────────────────────────────
function openDrawer(inc){
  el('drawerTitle').textContent=inc.id||'Incident Detail';
  el('drawerBody').innerHTML=`
    <div class="drawer-field"><label>Description</label><p>${inc.desc||'—'}</p></div>
    <div class="drawer-field"><label>Severity</label><p><span class="sev-badge ${sevClass(inc.sev)}">${inc.sev||'—'}</span></p></div>
    <div class="drawer-field"><label>Status</label><p><span class="status-chip ${statusClass(inc.status)}">${inc.status||'—'}</span></p></div>
    <div class="drawer-field"><label>Integration</label><p>${inc.integration||'—'}</p></div>
    <div class="drawer-field"><label>Environment</label><p>${inc.env||'—'}</p></div>
    <div class="drawer-field"><label>Users Affected</label><p>${inc.affected?inc.affected.toLocaleString():'—'}</p></div>
    <div class="drawer-field"><label>SLA Status</label><p>${inc.sla||'—'}</p></div>
    <div class="drawer-ai-box">
      <div class="drawer-ai-title">✦ Agentforce AI Analysis</div>
      <div class="drawer-field"><label>Root Cause</label><p>${inc.rootCause||'Analyzing…'}</p></div>
      <div class="drawer-field"><label>Recommended Action</label><p><span class="action-pill ${actionClass(inc.action)}">${inc.action||'—'}</span></p></div>
      <div class="drawer-field"><label>Confidence</label><p>${inc.confidence||'—'}%</p></div>
      <div class="drawer-field"><label>Impact Level</label><p>${inc.impact||'—'}</p></div>
    </div>
    <div style="margin-top:16px;display:flex;gap:8px">
      <button class="btn-primary" onclick="healIncident('${inc.id}')">⚡ Auto-Heal</button>
      <button class="btn-ghost" onclick="closeDrawer()">Close</button>
    </div>`;
  el('detailDrawer').classList.add('open');
}
function closeDrawer(){el('detailDrawer').classList.remove('open');}

function healIncident(id){
  closeDrawer();
  showToast(`⚡ Auto-healing initiated for ${id}`);
  setTimeout(()=>{
    const rows=document.querySelectorAll('#incidentsFullBody tr,#incidentTableBody tr');
    rows.forEach(r=>{if(r.innerHTML.includes(id)){const chips=r.querySelectorAll('.status-chip');chips.forEach(c=>{c.className='status-chip status-healing';c.textContent='Healing';});}});
  },500);
}

// ── FULL INCIDENTS ────────────────────────────────────────────────────────────
let incidentFilter={sev:'all',status:'all',search:''};
function renderFullIncidents(data){
  const tbody=el('incidentsFullBody');
  if(!tbody)return;
  tbody.innerHTML=data.map(i=>`
    <tr>
      <td><span style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--muted)">${i.id}</span></td>
      <td style="max-width:200px;white-space:normal">${i.desc}</td>
      <td><span class="sev-badge ${sevClass(i.sev)}">${i.sev}</span></td>
      <td><span class="status-chip ${statusClass(i.status)}">${i.status}</span></td>
      <td>${i.integration}</td>
      <td style="color:var(--muted);font-size:.72rem">${i.env}</td>
      <td>${i.affected.toLocaleString()}</td>
      <td><span style="font-size:.72rem;color:${i.sla==='Breached'?'var(--critical)':i.sla==='At Risk'?'var(--warning)':'var(--success)'}">${i.sla}</span></td>
      <td style="color:var(--muted);font-size:.72rem">${i.time}</td>
      <td><button class="action-btn" onclick='openDrawer(${JSON.stringify(i)})'>View →</button></td>
    </tr>`).join('');
}

function filterChip(el,val){
  document.querySelectorAll('.filter-chip').forEach(c=>c.classList.remove('active'));
  el.classList.add('active');
  let data=INCIDENTS;
  if(val!=='all'&&val!=='Open'&&val!=='Resolved')data=data.filter(i=>i.sev===val);
  else if(val==='Open')data=data.filter(i=>i.status==='Open'||i.status==='Investigating'||i.status==='Healing');
  else if(val==='Resolved')data=data.filter(i=>i.status==='Resolved');
  renderFullIncidents(data);
}

function searchIncidents(){
  const q=el('incidentSearch').value.toLowerCase();
  renderFullIncidents(INCIDENTS.filter(i=>i.desc.toLowerCase().includes(q)||i.id.toLowerCase().includes(q)||i.integration.toLowerCase().includes(q)));
}

function createIncident(){showToast('+ New incident form would open in Salesforce Experience Cloud');}

// ── INTEGRATIONS ──────────────────────────────────────────────────────────────
function renderIntegrations(){
  const grid=el('integrationsGrid');
  if(!grid)return;
  grid.innerHTML=INTEGRATIONS.map(i=>{
    const pct=parseFloat(i.uptime);
    return`<div class="int-card">
      <div class="int-card-top">
        <span class="int-name">${i.name}</span>
        <span class="int-status ${i.status==='OK'?'int-ok':i.status==='Failed'?'int-fail':'int-warn'}">${i.status}</span>
      </div>
      <div class="int-resp" style="color:${i.color}">${i.resp}</div>
      <div class="int-meta">Uptime: ${i.uptime} · Errors: ${i.errors} · Last OK: ${i.lastOk}</div>
      <div class="int-progress"><div class="int-fill" style="width:${pct}%;background:${i.color}"></div></div>
    </div>`;
  }).join('');
  renderLogs(LOGS);
}

function renderLogs(data){
  const tbody=el('integrationLogBody');
  if(!tbody)return;
  tbody.innerHTML=data.map(l=>`
    <tr>
      <td>${l.api}</td>
      <td><span class="sev-badge ${l.status==='Failed'?'sev-critical':l.status==='Warning'?'sev-medium':'sev-low'}">${l.status}</span></td>
      <td style="font-family:'JetBrains Mono',monospace;font-size:.72rem">${l.resp}</td>
      <td style="color:var(--muted);font-size:.75rem;max-width:200px">${l.error}</td>
      <td style="font-family:'JetBrains Mono',monospace;font-size:.72rem;color:var(--muted)">${l.ts}</td>
      <td><button class="action-btn" onclick="showToast('Agentforce analyzing ${l.api}…')">Analyze</button></td>
    </tr>`).join('');
}

function filterLogs(val){renderLogs(val==='all'?LOGS:LOGS.filter(l=>l.status===val));}
function refreshIntegrations(){showToast('↺ Integration data refreshed');renderIntegrations();}

// ── IMPACT ────────────────────────────────────────────────────────────────────
function renderImpact(){
  const totalRevLoss=IMPACT_DATA.reduce((s,i)=>s+i.users*i.arpu,0);
  const totalUsers=IMPACT_DATA.reduce((s,i)=>s+i.users,0);
  const hero=el('impactHero');
  if(hero)hero.innerHTML=`
    <div class="impact-stat-card">
      <div class="impact-stat-val" style="color:var(--critical)">${fmtMoney(totalRevLoss)}</div>
      <div class="impact-stat-label">Estimated Revenue at Risk</div>
      <span class="impact-stat-risk risk-critical">Critical</span>
    </div>
    <div class="impact-stat-card">
      <div class="impact-stat-val" style="color:var(--warning)">${totalUsers.toLocaleString()}</div>
      <div class="impact-stat-label">Total Users Affected</div>
      <span class="impact-stat-risk risk-high">High</span>
    </div>
    <div class="impact-stat-card">
      <div class="impact-stat-val" style="color:var(--accent)">${IMPACT_DATA.length}</div>
      <div class="impact-stat-label">Active Impact Events</div>
      <span class="impact-stat-risk risk-medium">Monitor</span>
    </div>`;
  const grid=el('impactDetailsGrid');
  if(grid)grid.innerHTML=IMPACT_DATA.map(i=>{
    const loss=i.users*i.arpu;
    return`<div class="impact-incident-card">
      <div class="impact-incident-title">${i.id} — ${i.title}</div>
      <div class="impact-row"><span>Incident Type</span><span>${i.type}</span></div>
      <div class="impact-row"><span>Users Affected</span><span>${i.users.toLocaleString()}</span></div>
      <div class="impact-row"><span>Avg Revenue/User</span><span>$${i.arpu}</span></div>
      <div class="impact-row"><span>Est. Revenue Loss</span><span style="color:var(--critical);font-weight:600">${fmtMoney(loss)}</span></div>
      <div class="impact-row"><span>Risk Level</span><span class="impact-stat-risk ${riskClass(i.risk)}" style="font-size:.68rem">${i.risk}</span></div>
      <div class="impact-row" style="border:none;margin-top:4px"><span style="font-size:.72rem;color:var(--muted)">AI Summary: ${i.users.toLocaleString()} users impacted, est. ${fmtMoney(loss)} revenue at risk — ${i.risk} priority.</span></div>
    </div>`;
  }).join('');
}

// ── COPILOT ───────────────────────────────────────────────────────────────────
const AI_RESPONSES={
  'what caused the api gateway failure':'**Root Cause Identified:**\n\nThe Payment API connection pool was exhausted at 04:12 UTC. A transaction volume spike (3.2x normal) saturated all 100 available connections. No circuit breaker was configured.\n\n**Recommended Action:** Restart the Payment API service and set circuit breaker threshold to 80% pool utilization.\n\n**Confidence:** 92%',
  'how many users are affected right now':'**Live User Impact:**\n\n• Critical incidents: **1,240 users** (Payment API)\n• High severity: **1,010 users** (Apex CPU + CRM Import)\n• Medium: **145 users**\n\n**Total affected: 2,395 users**\n\nAgentforce has initiated auto-heal on 3 incidents.',
  'estimate revenue loss from critical incidents':'**Business Impact Analysis:**\n\n| Incident | Users | Revenue at Risk |\n|---|---|---|\n| Payment API | 1,240 | $52,080 |\n| Apex CPU | 580 | $22,040 |\n| ERP Sync | 310 | $7,750 |\n| CRM Import | 430 | $12,900 |\n\n**Total Estimated Risk: $94,770**\n\nRisk Level: 🔴 **Critical**',
  'auto-heal the payment service integration':'**Auto-Heal Initiated ⚡**\n\nExecuting self-healing workflow for Payment API:\n\n1. ✅ Draining existing connections\n2. ✅ Restarting service pool\n3. ⏳ Validating health endpoint\n4. ⏳ Resuming traffic\n\nEstimated recovery time: **2-4 minutes**\n\nI will notify you when the integration returns to healthy status.',
  'show sla breach risk for next hour':'**SLA Breach Forecast (Next 60 min):**\n\n🔴 **INC-0041** — Already breached (Payment API)\n🟠 **INC-0040** — 12 min to breach (Apex CPU)\n🟡 **INC-0037** — 28 min to breach (CRM Import)\n🟢 All others — Within SLA\n\n**Recommendation:** Escalate INC-0040 immediately to prevent cascade.',
  'generate incident summary report':'**Incident Summary Report — Generated by Agentforce**\n\n**Period:** Last 24 hours\n**Total Incidents:** 7\n**Critical:** 2 | **High:** 2 | **Medium:** 2 | **Low:** 1\n\n**Resolution Stats:**\n• Auto-healed by AI: 12\n• Human escalations: 3\n• Avg resolution time: 18 min\n\n**Top Root Cause:** Connection pool exhaustion (2 incidents)\n\n*Report saved to Salesforce Reports → SEOMP Dashboard*',
};

let copilotInit=false;
function initCopilot(){
  if(copilotInit)return;
  copilotInit=true;
  const msgs=el('chatMessages');
  if(!msgs)return;
  msgs.innerHTML='';
  addAIMsg("Hi, I'm **SentinelFlow Copilot** powered by Agentforce.\n\nI have full visibility into your operations — incidents, integrations, SLA risk, and business impact. Ask me anything.");
}

function addAIMsg(text){
  const msgs=el('chatMessages');
  if(!msgs)return;
  const div=document.createElement('div');
  div.className='chat-msg ai';
  div.innerHTML=`<div class="msg-avatar ai">SF</div><div><div class="msg-bubble">${mdToHtml(text)}</div><div class="msg-meta">${new Date().toLocaleTimeString()} · Agentforce</div></div>`;
  msgs.appendChild(div);
  msgs.scrollTop=msgs.scrollHeight;
}

function addUserMsg(text){
  const msgs=el('chatMessages');
  if(!msgs)return;
  const div=document.createElement('div');
  div.className='chat-msg user';
  div.innerHTML=`<div class="msg-avatar user">OP</div><div><div class="msg-bubble">${text}</div><div class="msg-meta">${new Date().toLocaleTimeString()}</div></div>`;
  msgs.appendChild(div);
  msgs.scrollTop=msgs.scrollHeight;
}

function mdToHtml(t){
  return t.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/\n/g,'<br>').replace(/\|(.+)\|/g,(m,r)=>`<span style="font-family:'JetBrains Mono',monospace;font-size:.75rem">${m}</span>`);
}

function sendChat(){
  const input=el('chatInput');
  const text=input.value.trim();
  if(!text)return;
  addUserMsg(text);
  input.value='';
  showTyping();
  const key=text.toLowerCase().replace(/[^a-z0-9 ]/g,'');
  let response=null;
  for(const k of Object.keys(AI_RESPONSES)){if(key.includes(k.split(' ')[0])||k.includes(key.split(' ')[0])){response=AI_RESPONSES[k];break;}}
  if(!response)response=`I'm analyzing your query: **"${text}"**\n\nChecking incident data, integration health, and Salesforce telemetry...\n\nBased on current platform state: 4 critical alerts active, 2,341 users affected, $84K revenue at risk.\n\nWould you like me to drill into a specific incident or run an auto-heal?`;
  setTimeout(()=>{removeTyping();addAIMsg(response);},1500);
}

function askSuggestion(btn){
  const input=el('chatInput');
  if(input)input.value=btn.textContent;
  sendChat();
}

let typingEl=null;
function showTyping(){
  const msgs=el('chatMessages');
  if(!msgs)return;
  typingEl=document.createElement('div');
  typingEl.className='chat-msg ai';
  typingEl.innerHTML=`<div class="msg-avatar ai">SF</div><div class="typing"><div class="typing-dot"></div><div class="typing-dot"></div><div class="typing-dot"></div></div>`;
  msgs.appendChild(typingEl);
  msgs.scrollTop=msgs.scrollHeight;
}
function removeTyping(){if(typingEl){typingEl.remove();typingEl=null;}}

// ── AI ANALYSIS OVERLAY ───────────────────────────────────────────────────────
const STEPS=['Collecting telemetry signals','Running Agentforce inference','Identifying root causes','Calculating business impact','Generating recommendations'];
function runAIAnalysis(){
  const ov=el('aiOverlay');ov.classList.add('show');
  const bar=el('overlayBar');const stepEl=el('overlayStep');
  let i=0;
  const iv=setInterval(()=>{
    if(i>=STEPS.length){clearInterval(iv);setTimeout(()=>{ov.classList.remove('show');showToast('✦ AI Analysis complete — 3 root causes identified');},400);return;}
    stepEl.textContent=STEPS[i];bar.style.width=`${((i+1)/STEPS.length)*100}%`;i++;
  },700);
}

// ── TAILWIND TOAST ────────────────────────────────────────────────────────────
function showToast(msg, type = 'brand') {
  const container = el('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  const typeStyles = type === 'success' 
    ? 'border-green-500/50 bg-green-500/10 text-green-400' 
    : 'border-brand-500/50 bg-brand-500/10 text-brand-400';
    
  toast.className = `pointer-events-auto flex items-start gap-3 p-4 rounded-xl border ${typeStyles} backdrop-blur-md shadow-lg transform transition-all duration-300 translate-y-10 opacity-0`;
  
  toast.innerHTML = `
    <div class="flex-1">
      <p class="font-medium text-sm text-white">${msg}</p>
    </div>
    <button onclick="this.parentElement.remove()" class="text-white/50 hover:text-white transition">✕</button>
  `;
  
  container.appendChild(toast);
  
  // Animate In
  requestAnimationFrame(() => {
    toast.classList.remove('translate-y-10', 'opacity-0');
  });

  // Auto remove
  setTimeout(() => {
    toast.classList.add('opacity-0', 'translate-x-10');
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// ── INIT ──────────────────────────────────────────────────────────────────────
renderHomeIncidents(INCIDENTS.slice(0,5));
renderAIInsights();
