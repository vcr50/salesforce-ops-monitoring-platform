export default function HowItWorks() {
  return (
    <section className="how-it-works" id="how-it-works">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">WORKFLOW</span>
          <h2 className="section-title">How SentinelFlow <span className="gradient-text">Protects You</span></h2>
          <p className="section-subtitle">From the moment an integration fails to full resolution — in seconds, not hours.</p>
        </div>
        <div className="steps-timeline">
          <div className="step">
            <div className="step-number">01</div>
            <div className="step-content">
              <h3>Detect</h3>
              <p>Integration logs are monitored in real-time via Apex triggers. Failed transactions are instantly captured and queued for analysis.</p>
            </div>
          </div>
          <div className="step">
            <div className="step-number">02</div>
            <div className="step-content">
              <h3>Classify</h3>
              <p>The AI engine matches failure patterns against configurable rules (Custom Metadata), assigns severity, root cause, and business impact score.</p>
            </div>
          </div>
          <div className="step">
            <div className="step-number">03</div>
            <div className="step-content">
              <h3>Heal</h3>
              <p>Transient failures are automatically retried. Credential resets, queue restarts, and integration resyncs execute without human intervention.</p>
            </div>
          </div>
          <div className="step">
            <div className="step-number">04</div>
            <div className="step-content">
              <h3>Alert &amp; Report</h3>
              <p>Unresolvable incidents escalate to the right team. Full audit trails, dead-letter logs, and the observability dashboard provide complete visibility.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
