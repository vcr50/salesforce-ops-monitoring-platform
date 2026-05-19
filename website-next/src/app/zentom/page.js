import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import Image from 'next/image';
import styles from './page.module.css';

export const metadata = {
  title: 'Zentom — The Orchestration Moat | SentinelFlow',
  description: 'Explore the Zentom Orchestration System: eight AI engines, structural governance gates, and a hybrid model router powering SentinelFlow\'s autonomous business protection.',
};

const engines = [
  {
    icon: '🧠',
    title: 'Context Engine',
    desc: 'Assembles full situational awareness before any AI reasoning — past incidents, runbooks, account details, deployment history, and failure patterns.',
    tags: ['RAG', 'Salesforce', 'Knowledge Base', 'History'],
    colorClass: 'iconContext',
    colorVar: '#7b52ff',
  },
  {
    icon: '💾',
    title: 'Memory Engine',
    desc: 'Embeddings + RAG over PostgreSQL/pgvector. Recognizes failure patterns even without keyword matches. Builds institutional memory over time.',
    tags: ['pgvector', 'Redis', 'Embeddings', 'RAG'],
    colorClass: 'iconMemory',
    colorVar: '#00d2ff',
  },
  {
    icon: '🛡️',
    title: 'Policy Engine',
    desc: 'The governance spine. Evaluates AI recommendations against hard gates — confidence thresholds, production checks, risk blocks.',
    tags: ['Confidence Gate', 'Hard Rules', 'Escalation'],
    colorClass: 'iconPolicy',
    colorVar: '#ef4444',
  },
  {
    icon: '⚡',
    title: 'Risk Engine',
    desc: 'Quantifies danger across four dimensions: technical severity, business impact, blast radius, and operational context.',
    tags: ['Severity', 'ARR Impact', 'Blast Radius', 'Context'],
    colorClass: 'iconRisk',
    colorVar: '#f59e0b',
  },
  {
    icon: '🔄',
    title: 'Replay Engine',
    desc: 'Records every AI decision lifecycle in enough detail to be re-run or challenged. Powers audit, policy re-runs, model comparison, and post-mortems.',
    tags: ['Audit Trail', 'Post-mortem', 'Training Data'],
    colorClass: 'iconReplay',
    colorVar: '#10b981',
  },
  {
    icon: '📊',
    title: 'Evaluation Engine',
    desc: 'Judges AI performance by comparing recommendations against actual outcomes. Detects model drift and feeds three feedback loops.',
    tags: ['Accuracy', 'Drift Detection', 'Calibration'],
    colorClass: 'iconEval',
    colorVar: '#06b6d4',
  },
  {
    icon: '🎯',
    title: 'Execution Controller',
    desc: 'Final gate before production. Pre-execution checks, multi-step sequencing, and step verification with rollback on failure.',
    tags: ['Circuit Breaker', 'Idempotency', 'Rollback'],
    colorClass: 'iconExec',
    colorVar: '#ec4899',
  },
  {
    icon: '🔀',
    title: 'Model Router',
    desc: 'Selects the optimal AI model combination based on task type, risk level, latency requirements, and confidence needs.',
    tags: ['R1', 'Coder', 'Llama 3', 'Agentforce'],
    colorClass: 'iconRouter',
    colorVar: '#7b52ff',
  },
];

const models = [
  {
    icon: '🧪',
    name: 'DeepSeek R1',
    role: 'Primary Reasoning Engine',
    weight: '45%',
    weightClass: 'modelWeightPrimary',
    iconClass: 'iconContext',
    dotColor: '#7b52ff',
    desc: 'Trained via reinforcement learning with emergent self-reflection, verification, and dynamic strategy adaptation. Handles multi-system failures, ambiguous root causes, and novel failure types.',
    capabilities: [
      'Multi-system failure diagnosis',
      'Chain-of-thought reasoning',
      'High-revenue-risk incident prioritization',
      'Final reasoning authority for low-confidence escalation',
    ],
  },
  {
    icon: '⚙️',
    name: 'Agentforce',
    role: 'Salesforce-Native Execution',
    weight: '20%',
    weightClass: 'modelWeightSecondary',
    iconClass: 'iconMemory',
    dotColor: '#00d2ff',
    desc: 'Runs inside the Salesforce Trust Layer with native access to all objects and full permission enforcement. Handles the return path — cases, flows, records.',
    capabilities: [
      'Trust Layer compliance',
      'Step-verified execution with retry/failover',
      'Full Salesforce object access',
      'AppExchange-compatible distribution',
    ],
  },
  {
    icon: '🦙',
    name: 'Llama 3',
    role: 'Local Inference via Ollama',
    weight: '10%',
    weightClass: 'modelWeightTertiary',
    iconClass: 'iconReplay',
    dotColor: '#10b981',
    desc: 'Zero-latency local inference for initial triage and classification. Runs via Ollama with no external API calls — speed over reasoning depth.',
    capabilities: [
      'Zero-latency local execution',
      'Initial triage and classification',
      'Low-risk recommendation generation',
      'Privacy-preserving on-device inference',
    ],
  },
  {
    icon: '💻',
    name: 'DeepSeek Coder',
    role: 'Code Analysis Engine',
    weight: '10%',
    weightClass: 'modelWeightQuaternary',
    iconClass: 'iconRisk',
    dotColor: '#f59e0b',
    desc: 'Processes code as structured text — call graphs, dependency chains, type hierarchies. Diagnoses Flow failures, Apex bugs, and SOQL errors.',
    capabilities: [
      'Salesforce Flow & Apex failure analysis',
      'LWC frontend code diagnosis',
      'API payload & schema mismatch detection',
      'Structured output with file, line, severity',
    ],
  },
];

const governanceGates = [
  {
    number: '1',
    title: 'Risk Evaluation',
    desc: 'Every action must pass a quantified risk assessment measuring Technical Severity, Business Impact, Blast Radius, and Operational Context.',
    rules: [
      { text: 'Risk Score → 4 Dimensions', type: 'govRulePass' },
    ],
    color: '#7b52ff',
    bg: 'rgba(123, 82, 255, 0.1)',
  },
  {
    number: '2',
    title: 'Policy Validation',
    desc: 'The final action must be cleared by the Policy Engine against hard gates. Production systems always trigger escalation regardless of confidence.',
    rules: [
      { text: 'confidence < 80% → human', type: 'govRuleEscalate' },
      { text: 'prod system → escalate', type: 'govRuleEscalate' },
      { text: 'high risk → block', type: 'govRuleBlock' },
    ],
    color: '#ef4444',
    bg: 'rgba(239, 68, 68, 0.1)',
  },
  {
    number: '3',
    title: 'Confidence & AI Guardian Gate',
    desc: 'Autonomous execution is strictly blocked when confidence is below 80%, Revenue Risk exceeds $50,000, or the action involves irreversible data changes.',
    rules: [
      { text: 'confidence < 80% → BLOCK', type: 'govRuleBlock' },
      { text: 'revenue risk > $50K → BLOCK', type: 'govRuleBlock' },
      { text: 'irreversible action → BLOCK', type: 'govRuleBlock' },
    ],
    color: '#f59e0b',
    bg: 'rgba(245, 158, 11, 0.1)',
  },
  {
    number: '4',
    title: 'Replay Logging',
    desc: 'Every step of the decision lifecycle — context, prompt/response, risk scores, policy outcomes, final action — is logged for audit and metrics.',
    rules: [
      { text: 'Full trace recorded', type: 'govRulePass' },
    ],
    color: '#10b981',
    bg: 'rgba(16, 185, 129, 0.1)',
  },
  {
    number: '5',
    title: 'Execution',
    desc: 'Upon clearance, the Execution Controller manages pre-execution checks, sequencing, and step verification before dispatching via Agentforce.',
    rules: [
      { text: 'Circuit breaker check', type: 'govRuleEscalate' },
      { text: 'Step-by-step verification', type: 'govRulePass' },
      { text: 'Rollback on failure', type: 'govRulePass' },
    ],
    color: '#ec4899',
    bg: 'rgba(236, 72, 153, 0.1)',
  },
];

const actions = [
  {
    name: 'Notify Teams',
    risk: 'Lowest',
    riskClass: 'riskLowest',
    desc: 'Zero production side effects. Sends notifications without any risk of making a bad situation worse.',
    autonomy: 'Fully autonomous from Phase 4',
  },
  {
    name: 'Open Case',
    risk: 'Low',
    riskClass: 'riskLow',
    desc: 'Creates Salesforce cases for incident tracking. No production state changes — always safe to automate.',
    autonomy: 'Fully autonomous from Phase 4',
  },
  {
    name: 'Retry Integration',
    risk: 'Medium',
    riskClass: 'riskMedium',
    desc: 'Circuit breaker checked first. If the integration has already failed multiple times, retry is held rather than worsening flapping.',
    autonomy: 'Non-prod: auto · Prod: risk-scored',
  },
  {
    name: 'Trigger SF Flow',
    risk: 'Variable',
    riskClass: 'riskVariable',
    desc: 'Risk depends entirely on what the Flow does. A notification Flow is low risk; a billing Flow triggers Gate 2 production check.',
    autonomy: 'Varies by Flow target',
  },
  {
    name: 'Restart Workflow',
    risk: 'High',
    riskClass: 'riskHigh',
    desc: 'Phase 4 MVP goal. Stop → confirm stopped → restart. Well-understood recovery for stuck Salesforce workflows.',
    autonomy: 'Non-prod: auto · Prod: human approval',
  },
  {
    name: 'Rollback Deployment',
    risk: 'Highest',
    riskClass: 'riskHighest',
    desc: 'Requires joint DeepSeek Coder + R1 analysis. Most consequential action — AI presents evidence, human makes the final call.',
    autonomy: 'Always requires human approval',
  },
];

export default function ZentomPage() {
  return (
    <>
      <Navbar />

      {/* ═══════ HERO ═══════ */}
      <section className={styles.heroSection} id="zentom-hero">
        <div className={styles.heroBgEffects}>
          <div className={`${styles.heroOrb} ${styles.heroOrb1}`} />
          <div className={`${styles.heroOrb} ${styles.heroOrb2}`} />
          <div className={`${styles.heroOrb} ${styles.heroOrb3}`} />
          <div className={styles.heroGrid} />
        </div>

        <div className={styles.heroContent}>
          <div className={styles.heroBadge}>
            <span className={styles.badgeDot} />
            The Orchestration Moat
          </div>

          <h1 className={styles.heroTitle}>
            <span className={styles.heroTitleGradient}>Zentom</span>
            <br />
            Orchestration System
          </h1>

          <p className={styles.heroSubtitle}>
            Eight AI engines. Five governance gates. One reasoning-first strategy.
            Zentom is what Tomcodex owns end-to-end — not a wrapper around third-party models,
            but the full orchestration stack that ensures no LLM action ever touches production
            without structural governance.
          </p>

          <div className={styles.heroStats}>
            <div className={styles.heroStat}>
              <div className={styles.heroStatValue}>8</div>
              <span className={styles.heroStatLabel}>Engine Components</span>
            </div>
            <div className={styles.heroStatDivider} />
            <div className={styles.heroStat}>
              <div className={styles.heroStatValue}>5</div>
              <span className={styles.heroStatLabel}>Governance Gates</span>
            </div>
            <div className={styles.heroStatDivider} />
            <div className={styles.heroStat}>
              <div className={styles.heroStatValue}>4</div>
              <span className={styles.heroStatLabel}>AI Models</span>
            </div>
            <div className={styles.heroStatDivider} />
            <div className={styles.heroStat}>
              <div className={styles.heroStatValue}>45%</div>
              <span className={styles.heroStatLabel}>R1 Reasoning Weight</span>
            </div>
          </div>
        </div>
      </section>

      {/* ═══════ ARCHITECTURE FLOW ═══════ */}
      <section className={`${styles.section} ${styles.sectionAlt}`} id="zentom-architecture">
        <div className={styles.sectionInner}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionTag}>System Architecture</span>
            <h2 className={styles.sectionTitle}>
              How Data Flows Through <span className={styles.heroTitleGradient}>Zentom</span>
            </h2>
            <p className={styles.sectionSubtitle}>
              Every incident follows a governed, traceable path from Salesforce through
              the intelligence stack and back — with five mandatory gates in between.
            </p>
          </div>

          <div className={styles.archFlow}>
            {/* Salesforce Layer */}
            <div className={styles.archLayer}>
              <div className={`${styles.archLayerCard} ${styles.archLayerSalesforce}`}>
                <div className={styles.archLayerLabel}>
                  <div className={`${styles.archLayerIcon} ${styles.iconSalesforce}`}>☁️</div>
                  <div>
                    <div className={styles.archLayerTitle}>Salesforce</div>
                    <div className={styles.archLayerSubtitle}>System of Record</div>
                  </div>
                </div>
                <p className={styles.archLayerDesc}>
                  Authoritative source of truth for incidents, cases, accounts, contracts, and revenue data.
                  Publishes Platform Events on failure — SentinelFlow subscribes and reacts.
                </p>
                <div className={styles.archLayerChips}>
                  <span className={styles.archChip}>Accounts</span>
                  <span className={styles.archChip}>Cases</span>
                  <span className={styles.archChip}>Contracts</span>
                  <span className={styles.archChip}>Revenue</span>
                  <span className={styles.archChip}>Platform Events</span>
                </div>
              </div>
            </div>

            {/* Arrow */}
            <div className={styles.archArrow}>
              <div className={styles.archArrowLine} />
              <span className={styles.archArrowLabel}>Platform Events</span>
              <div className={styles.archArrowHead} />
            </div>

            {/* Core Layer */}
            <div className={styles.archLayer}>
              <div className={`${styles.archLayerCard} ${styles.archLayerCore}`}>
                <div className={styles.archLayerLabel}>
                  <div className={`${styles.archLayerIcon} ${styles.iconCore}`}>🔍</div>
                  <div>
                    <div className={styles.archLayerTitle}>SentinelFlow Core</div>
                    <div className={styles.archLayerSubtitle}>Analysis & Routing Layer</div>
                  </div>
                </div>
                <p className={styles.archLayerDesc}>
                  Receives Platform Events, extracts structured incident data, performs revenue-aware
                  prioritization, and applies the 80% Confidence Gate before routing to Zentom.
                </p>
                <div className={styles.archLayerChips}>
                  <span className={styles.archChip}>Analyzer</span>
                  <span className={styles.archChip}>Prioritizer</span>
                  <span className={styles.archChip}>Confidence Gate</span>
                  <span className={styles.archChip}>Router</span>
                  <span className={styles.archChip}>Tracer</span>
                </div>
              </div>
            </div>

            {/* Arrow */}
            <div className={styles.archArrow}>
              <div className={styles.archArrowLine} />
              <span className={styles.archArrowLabel}>Enriched Context</span>
              <div className={styles.archArrowHead} />
            </div>

            {/* Zentom Layer */}
            <div className={styles.archLayer}>
              <div className={`${styles.archLayerCard} ${styles.archLayerZentom}`}>
                <div className={styles.archLayerLabel}>
                  <div className={`${styles.archLayerIcon} ${styles.iconZentom}`}>🧠</div>
                  <div>
                    <div className={styles.archLayerTitle}>Zentom Orchestration System</div>
                    <div className={styles.archLayerSubtitle}>The Orchestration Moat</div>
                  </div>
                </div>
                <p className={styles.archLayerDesc}>
                  Eight engine components working in concert: Context, Memory, Policy, Risk, Replay,
                  Evaluation, Execution Controller, and Model Router. Every AI decision passes through
                  structural governance before reaching production.
                </p>
                <div className={styles.archLayerChips}>
                  <span className={styles.archChip}>Context</span>
                  <span className={styles.archChip}>Memory</span>
                  <span className={styles.archChip}>Policy</span>
                  <span className={styles.archChip}>Risk</span>
                  <span className={styles.archChip}>Replay</span>
                  <span className={styles.archChip}>Evaluation</span>
                  <span className={styles.archChip}>Execution</span>
                  <span className={styles.archChip}>Model Router</span>
                </div>
              </div>
            </div>

            {/* Arrow */}
            <div className={styles.archArrow}>
              <div className={styles.archArrowLine} />
              <span className={styles.archArrowLabel}>Governed Action</span>
              <div className={styles.archArrowHead} />
            </div>

            {/* Agentforce Layer */}
            <div className={styles.archLayer}>
              <div className={`${styles.archLayerCard} ${styles.archLayerAgentforce}`}>
                <div className={styles.archLayerLabel}>
                  <div className={`${styles.archLayerIcon} ${styles.iconAgentforce}`}>🤖</div>
                  <div>
                    <div className={styles.archLayerTitle}>Agentforce</div>
                    <div className={styles.archLayerSubtitle}>Salesforce-Native Execution</div>
                  </div>
                </div>
                <p className={styles.archLayerDesc}>
                  Translates Zentom&apos;s governed decisions into actual Salesforce operations —
                  opening cases, triggering Flows, updating records, and managing rollbacks with
                  full Trust Layer compliance.
                </p>
                <div className={styles.archLayerChips}>
                  <span className={styles.archChip}>Cases</span>
                  <span className={styles.archChip}>Flows</span>
                  <span className={styles.archChip}>Record Updates</span>
                  <span className={styles.archChip}>Notifications</span>
                  <span className={styles.archChip}>Rollbacks</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ═══════ EIGHT ENGINES ═══════ */}
      <section className={styles.section} id="zentom-engines">
        <div className={styles.sectionInner}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionTag}>The Eight Engines</span>
            <h2 className={styles.sectionTitle}>
              Every Component of the <span className={styles.heroTitleGradient}>Moat</span>
            </h2>
            <p className={styles.sectionSubtitle}>
              Each engine has a distinct function. Together, they form the orchestration layer
              that makes autonomous AI actions trustworthy at enterprise scale.
            </p>
          </div>

          <div className={styles.enginesGrid}>
            {engines.map((engine) => (
              <div
                key={engine.title}
                className={styles.engineCard}
                style={{ '--engine-color': engine.colorVar }}
              >
                <div className={`${styles.engineIcon} ${styles[engine.colorClass]}`}>
                  {engine.icon}
                </div>
                <h3 className={styles.engineTitle}>{engine.title}</h3>
                <p className={styles.engineDesc}>{engine.desc}</p>
                <div className={styles.engineMeta}>
                  {engine.tags.map((tag) => (
                    <span key={tag} className={styles.engineMetaTag}>{tag}</span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ AI MODELS ═══════ */}
      <section className={`${styles.section} ${styles.sectionAlt}`} id="zentom-models">
        <div className={styles.sectionInner}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionTag}>Hybrid AI Layer</span>
            <h2 className={styles.sectionTitle}>
              Reasoning-First <span className={styles.heroTitleGradient}>Model Strategy</span>
            </h2>
            <p className={styles.sectionSubtitle}>
              Four specialized models, routed intelligently. DeepSeek R1 does the heavy inference.
              Agentforce executes in Salesforce. Llama 3 handles speed. Coder handles code.
            </p>
          </div>

          <div className={styles.modelsGrid}>
            {models.map((model) => (
              <div key={model.name} className={styles.modelCard}>
                <div className={styles.modelCardHeader}>
                  <div className={`${styles.modelIcon} ${styles[model.iconClass]}`}>
                    {model.icon}
                  </div>
                  <span className={`${styles.modelWeight} ${styles[model.weightClass]}`}>
                    {model.weight}
                  </span>
                </div>
                <h3 className={styles.modelName}>{model.name}</h3>
                <div className={styles.modelRole}>{model.role}</div>
                <p className={styles.modelDesc}>{model.desc}</p>
                <div className={styles.modelCapabilities}>
                  {model.capabilities.map((cap) => (
                    <div key={cap} className={styles.modelCapItem}>
                      <span
                        className={styles.modelCapDot}
                        style={{ background: model.dotColor }}
                      />
                      {cap}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ GOVERNANCE GATES ═══════ */}
      <section className={styles.section} id="zentom-governance">
        <div className={styles.sectionInner}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionTag}>Structural Governance</span>
            <h2 className={styles.sectionTitle}>
              Five Gates to <span className={styles.heroTitleGradient}>Production</span>
            </h2>
            <p className={styles.sectionSubtitle}>
              No LLM action touches a production system without mandatory passage through
              five sequential governance and control gates. This is the architecture, not a policy.
            </p>
          </div>

          <div className={styles.dashboardContainer}>
            <Image 
              src="/zentom-replay.png" 
              alt="Zentom Replay Dashboard" 
              width={1200} 
              height={675} 
              className={styles.dashboardImage}
              priority
            />
          </div>

          <div className={styles.govTimeline}>
            <div className={styles.govTimelineLine} />

            {governanceGates.map((gate) => (
              <div key={gate.number} className={styles.govGate}>
                <div
                  className={styles.govGateNumber}
                  style={{
                    background: gate.bg,
                    color: gate.color,
                    border: `2px solid ${gate.color}`,
                  }}
                >
                  {gate.number}
                </div>
                <div className={styles.govGateContent}>
                  <h3 className={styles.govGateTitle}>{gate.title}</h3>
                  <p className={styles.govGateDesc}>{gate.desc}</p>
                  <div className={styles.govGateRules}>
                    {gate.rules.map((rule) => (
                      <span key={rule.text} className={`${styles.govRule} ${styles[rule.type]}`}>
                        {rule.text}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ GOVERNED ACTIONS ═══════ */}
      <section className={`${styles.section} ${styles.sectionAlt}`} id="zentom-actions">
        <div className={styles.sectionInner}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionTag}>Autonomous Actions</span>
            <h2 className={styles.sectionTitle}>
              The Risk <span className={styles.heroTitleGradient}>Gradient</span>
            </h2>
            <p className={styles.sectionSubtitle}>
              Six action types form a natural risk spectrum. The governance stack is the same for all —
              but thresholds and approval requirements tighten as risk increases.
            </p>
          </div>

          <div className={styles.actionsGrid}>
            {actions.map((action) => (
              <div key={action.name} className={styles.actionCard}>
                <div className={styles.actionHeader}>
                  <span className={styles.actionName}>{action.name}</span>
                  <span className={`${styles.actionRisk} ${styles[action.riskClass]}`}>
                    {action.risk}
                  </span>
                </div>
                <p className={styles.actionDesc}>{action.desc}</p>
                <span className={styles.actionAutonomy}>{action.autonomy}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ═══════ CTA ═══════ */}
      <section className={styles.ctaSection} id="zentom-cta">
        <div className={styles.ctaGlow} />
        <h2 className={styles.ctaTitle}>
          This is the <span className={styles.heroTitleGradient}>Moat</span>
        </h2>
        <p className={styles.ctaSubtitle}>
          Zentom is what makes SentinelFlow more than an AI wrapper.
          Eight engines. Five gates. Full auditability. Enterprise trust.
        </p>
        <div className={styles.ctaActions}>
          <a href="/#pricing" className="btn btn-primary btn-lg">Start Free Trial</a>
          <a href="/contact" className="btn btn-outline btn-lg">Talk to Engineering</a>
        </div>
      </section>

      <Footer />
    </>
  );
}
