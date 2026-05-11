'use client';

const capabilities = [
  {
    icon: '🔍',
    title: 'Autonomous Incident Triage',
    desc: 'Agent reads every incident, determines severity, and prioritizes resolution — zero human clicks required.',
    color: 'purple',
  },
  {
    icon: '⚡',
    title: 'Auto Self-Healing',
    desc: 'Agent triggers SentinelFlow\'s healing engine automatically, resolving critical issues before users notice.',
    color: 'blue',
  },
  {
    icon: '📣',
    title: 'Customer Communication',
    desc: 'Agent proactively notifies affected portal users via Experience Cloud with real-time status updates.',
    color: 'green',
  },
  {
    icon: '📋',
    title: 'RCA Report Generation',
    desc: 'After resolution, the Agent writes a full Root Cause Analysis report and attaches it to the Incident record.',
    color: 'orange',
  },
  {
    icon: '📈',
    title: 'Smart Escalation',
    desc: 'Agent intelligently decides when human intervention is needed and escalates via Slack or Teams instantly.',
    color: 'pink',
  },
  {
    icon: '🧠',
    title: 'Continuous Learning',
    desc: 'Each resolved incident trains the Agent to handle similar issues faster and smarter in the future.',
    color: 'cyan',
  },
];

export default function AgentforceSection() {
  return (
    <section className="agentforce-section" id="agentforce">
      <div className="container">
        <div className="agentforce-header">
          <div className="agentforce-coming-soon">
            <span className="af-dot"></span> Coming Soon
          </div>
          <div className="agentforce-powered">
            <span className="af-logo">✦</span>
            <span>Powered by</span>
            <strong>Agentforce</strong>
          </div>
          <h2 className="section-title">
            From Automated to <span className="gradient-text">Autonomous</span>
          </h2>
          <p className="section-subtitle">
            SentinelFlow is integrating Salesforce Agentforce to take incident resolution to the next level — 
            a fully autonomous AI Agent that detects, heals, communicates, and reports without any human intervention.
          </p>
        </div>

        {/* Flow diagram */}
        <div className="af-flow">
          {['Detect', 'Analyze', 'Heal', 'Notify', 'Report'].map((step, i) => (
            <div key={step} className="af-flow-item">
              <div className="af-flow-step">{step}</div>
              {i < 4 && <div className="af-flow-arrow">→</div>}
            </div>
          ))}
        </div>

        {/* Capability cards */}
        <div className="af-grid">
          {capabilities.map((cap) => (
            <div key={cap.title} className="af-card">
              <div className={`af-icon af-icon-${cap.color}`}>{cap.icon}</div>
              <h3>{cap.title}</h3>
              <p>{cap.desc}</p>
            </div>
          ))}
        </div>

        {/* Bottom CTA */}
        <div className="af-cta">
          <div className="af-cta-badge">🚀 Launching with SentinelFlow v2.6.0</div>
          <p>Be the first to experience truly autonomous incident management on the Salesforce platform.</p>
        </div>
      </div>
    </section>
  );
}
