import { LightningElement, api, track } from 'lwc';

const ENGINES = [
    { id: 'context', icon: '🧠', title: 'Context Engine', desc: 'Assembles full situational awareness — past incidents, runbooks, account details, deployment history, and failure patterns.', tags: 'RAG · Salesforce · Knowledge Base · History', color: '#7b52ff' },
    { id: 'memory', icon: '💾', title: 'Memory Engine', desc: 'Embeddings + RAG over PostgreSQL/pgvector. Recognizes failure patterns even without keyword matches.', tags: 'pgvector · Redis · Embeddings · RAG', color: '#00d2ff' },
    { id: 'policy', icon: '🛡️', title: 'Policy Engine', desc: 'The governance spine. Evaluates AI recommendations against hard gates — confidence, production checks, risk blocks.', tags: 'Confidence Gate · Hard Rules · Escalation', color: '#ef4444' },
    { id: 'risk', icon: '⚡', title: 'Risk Engine', desc: 'Quantifies danger across four dimensions: technical severity, business impact, blast radius, and operational context.', tags: 'Severity · ARR Impact · Blast Radius', color: '#f59e0b' },
    { id: 'replay', icon: '🔄', title: 'Replay Engine', desc: 'Records every AI decision lifecycle in enough detail to be re-run or challenged. Powers audit and post-mortems.', tags: 'Audit Trail · Post-mortem · Training Data', color: '#10b981' },
    { id: 'eval', icon: '📊', title: 'Evaluation Engine', desc: 'Judges AI performance by comparing recommendations against actual outcomes. Detects model drift.', tags: 'Accuracy · Drift Detection · Calibration', color: '#06b6d4' },
    { id: 'exec', icon: '🎯', title: 'Execution Controller', desc: 'Final gate before production. Pre-execution checks, multi-step sequencing, step verification with rollback.', tags: 'Circuit Breaker · Idempotency · Rollback', color: '#ec4899' },
    { id: 'router', icon: '🔀', title: 'Model Router', desc: 'Selects the optimal AI model combination based on task type, risk level, latency, and confidence needs.', tags: 'R1 · Coder · Llama 3 · Agentforce', color: '#7b52ff' }
];

const MODELS = [
    { id: 'r1', icon: '🧪', name: 'DeepSeek R1', role: 'Primary Reasoning Engine', weight: '45%', weightTone: 'primary', desc: 'Trained via reinforcement learning with emergent self-reflection, verification, and dynamic strategy adaptation. Handles multi-system failures and novel failure types.', caps: ['Multi-system failure diagnosis', 'Chain-of-thought reasoning', 'High-revenue-risk prioritization', 'Low-confidence escalation authority'] },
    { id: 'af', icon: '⚙️', name: 'Agentforce', role: 'Salesforce-Native Execution', weight: '20%', weightTone: 'secondary', desc: 'Runs inside the Salesforce Trust Layer with native access to all objects and full permission enforcement. Handles the return path — cases, flows, records.', caps: ['Trust Layer compliance', 'Step-verified execution', 'Full Salesforce object access', 'AppExchange compatibility'] },
    { id: 'llama', icon: '🦙', name: 'Llama 3', role: 'Local Inference via Ollama', weight: '10%', weightTone: 'tertiary', desc: 'Zero-latency local inference for initial triage and classification. Runs via Ollama with no external API calls.', caps: ['Zero-latency local execution', 'Initial triage and classification', 'Low-risk recommendations', 'Privacy-preserving inference'] },
    { id: 'coder', icon: '💻', name: 'DeepSeek Coder', role: 'Code Analysis Engine', weight: '10%', weightTone: 'quaternary', desc: 'Processes code as structured text — call graphs, dependency chains, type hierarchies. Diagnoses Flow failures and Apex bugs.', caps: ['Salesforce Flow & Apex analysis', 'LWC frontend diagnosis', 'API schema mismatch detection', 'Structured file/line output'] }
];

const GATES = [
    { id: 'g1', num: '1', title: 'Risk Evaluation', desc: 'Every action must pass a quantified risk assessment measuring Technical Severity, Business Impact, Blast Radius, and Operational Context.', rules: [{ text: 'Risk Score → 4 Dimensions', tone: 'pass' }] },
    { id: 'g2', num: '2', title: 'Policy Validation', desc: 'The final action must be cleared by the Policy Engine against hard gates. Production systems always trigger escalation.', rules: [{ text: 'confidence < 80% → human', tone: 'escalate' }, { text: 'prod system → escalate', tone: 'escalate' }, { text: 'high risk → block', tone: 'block' }] },
    { id: 'g3', num: '3', title: 'Confidence & AI Guardian', desc: 'Autonomous execution is blocked when confidence < 80%, Revenue Risk > $50K, or the action involves irreversible data changes.', rules: [{ text: 'confidence < 80% → BLOCK', tone: 'block' }, { text: 'revenue > $50K → BLOCK', tone: 'block' }, { text: 'irreversible → BLOCK', tone: 'block' }] },
    { id: 'g4', num: '4', title: 'Replay Logging', desc: 'Every step of the decision lifecycle is logged — context, prompt/response, risk scores, policy outcomes, final action.', rules: [{ text: 'Full trace recorded', tone: 'pass' }] },
    { id: 'g5', num: '5', title: 'Execution', desc: 'The Execution Controller manages pre-execution checks, sequencing, and step verification before dispatching via Agentforce.', rules: [{ text: 'Circuit breaker check', tone: 'escalate' }, { text: 'Step-by-step verify', tone: 'pass' }, { text: 'Rollback on failure', tone: 'pass' }] }
];

const ACTIONS = [
    { id: 'a1', name: 'Notify Teams', risk: 'Lowest', riskTone: 'lowest', desc: 'Zero production side effects. Sends notifications safely.', autonomy: 'Fully autonomous' },
    { id: 'a2', name: 'Open Case', risk: 'Low', riskTone: 'low', desc: 'Creates Salesforce cases for incident tracking.', autonomy: 'Fully autonomous' },
    { id: 'a3', name: 'Retry Integration', risk: 'Medium', riskTone: 'medium', desc: 'Circuit breaker checked first. Holds retry if flapping detected.', autonomy: 'Non-prod: auto · Prod: risk-scored' },
    { id: 'a4', name: 'Trigger SF Flow', risk: 'Variable', riskTone: 'variable', desc: 'Risk depends on Flow target. Billing Flows trigger Gate 2.', autonomy: 'Varies by Flow target' },
    { id: 'a5', name: 'Restart Workflow', risk: 'High', riskTone: 'high', desc: 'Stop → confirm stopped → restart. Phase 4 MVP goal.', autonomy: 'Prod: human approval required' },
    { id: 'a6', name: 'Rollback Deploy', risk: 'Highest', riskTone: 'highest', desc: 'Joint DeepSeek Coder + R1 analysis. Human makes the final call.', autonomy: 'Always requires human approval' }
];

export default class SentinelFlowZentomArchitecture extends LightningElement {
    @api theme = 'dark';

    engines = ENGINES;
    models = MODELS;
    gates = GATES;
    actions = ACTIONS;

    @track activeSection = 'overview';

    get containerClass() {
        return `zentom-container ${this.theme === 'dark' ? 'theme-dark' : 'theme-light'}`;
    }

    get isOverview() { return this.activeSection === 'overview'; }
    get isEngines() { return this.activeSection === 'engines'; }
    get isModels() { return this.activeSection === 'models'; }
    get isGovernance() { return this.activeSection === 'governance'; }
    get isActions() { return this.activeSection === 'actions'; }

    get overviewTabClass() { return this.activeSection === 'overview' ? 'tab-btn active' : 'tab-btn'; }
    get enginesTabClass() { return this.activeSection === 'engines' ? 'tab-btn active' : 'tab-btn'; }
    get modelsTabClass() { return this.activeSection === 'models' ? 'tab-btn active' : 'tab-btn'; }
    get governanceTabClass() { return this.activeSection === 'governance' ? 'tab-btn active' : 'tab-btn'; }
    get actionsTabClass() { return this.activeSection === 'actions' ? 'tab-btn active' : 'tab-btn'; }

    handleTabClick(event) {
        this.activeSection = event.currentTarget.dataset.section;
    }

    get processedModels() {
        return this.models.map(m => ({
            ...m,
            weightClass: `weight-badge weight-${m.weightTone}`,
            processedCaps: m.caps.map((c, i) => ({ id: `${m.id}-cap-${i}`, text: c }))
        }));
    }

    get processedGates() {
        return this.gates.map(g => ({
            ...g,
            processedRules: g.rules.map((r, i) => ({
                id: `${g.id}-rule-${i}`,
                text: r.text,
                ruleClass: `rule-chip rule-${r.tone}`
            }))
        }));
    }

    get processedActions() {
        return this.actions.map(a => ({
            ...a,
            riskClass: `risk-badge risk-${a.riskTone}`
        }));
    }
}