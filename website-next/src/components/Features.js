export default function Features() {
  return (
    <section className="features" id="features">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">PLATFORM CAPABILITIES</span>
          <h2 className="section-title">Everything You Need for<br /><span className="gradient-text">Autonomous Salesforce Ops</span></h2>
          <p className="section-subtitle">Version 2.6 adds operational memory, prediction V2, adaptive runbooks, learning loops, and reliability simulation to the full AppExchange-ready product.</p>
        </div>
        <div className="features-grid">
          <div className="feature-card" data-aos="fade-up">
            <div className="feature-icon feature-icon-purple">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm0 14a1 1 0 1 1 1-1 1 1 0 0 1-1 1zm1-5a1 1 0 0 1-2 0V7a1 1 0 0 1 2 0z"/></svg>
            </div>
            <h3>Real-Time Detection</h3>
            <p>Platform Events and triggers detect integration failures the instant they occur. Zero delay, zero blind spots.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="100">
            <div className="feature-icon feature-icon-blue">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
            </div>
            <h3>AI Classification</h3>
            <p>AI classifies incident type, severity, root cause, memory matches, and business impact automatically.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="200">
            <div className="feature-icon feature-icon-green">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            </div>
            <h3>Self-Healing Runbooks</h3>
            <p>Approved runbooks refresh OAuth, retry failed calls, pause batches, and requeue jobs with validation and audit trails.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="300">
            <div className="feature-icon feature-icon-orange">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
            </div>
            <h3>Operational Memory</h3>
            <p>Every incident becomes searchable memory with root cause, remediation, success rate, MTTR, and tenant-isolated embeddings.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="400">
            <div className="feature-icon feature-icon-pink">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>
            </div>
            <h3>Prediction V2</h3>
            <p>Failure probability, deployment risk, flow instability, latency trends, and org stability scoring help teams act before impact.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="500">
            <div className="feature-icon feature-icon-cyan">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            </div>
            <h3>Learning Loop</h3>
            <p>Successful and failed recoveries adjust runbook confidence, suppress false positives, and improve future recommendations.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="600">
            <div className="feature-icon feature-icon-cyan">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 19h16"/><path d="M7 16l3-6 4 4 3-8"/></svg>
            </div>
            <h3>Dashboard V2</h3>
            <p>Executive AI Ops views show org health, confidence, deployment risk, heatmaps, recovery timelines, and auto-heal analytics.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="700">
            <div className="feature-icon feature-icon-purple">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 3v18"/><path d="M3 12h18"/><path d="M5 5l14 14"/><path d="M19 5L5 19"/></svg>
            </div>
            <h3>Reliability Simulation</h3>
            <p>Chaos scenarios test governor limits, retry storms, event spikes, failover, rollback, and integration timeouts.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="800">
            <div className="feature-icon feature-icon-green">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            </div>
            <h3>AppExchange Readiness</h3>
            <p>Versioned Salesforce package metadata, publisher copy, security review packet planning, and packaging checklist are tracked.</p>
          </div>
        </div>
      </div>
    </section>
  );
}
