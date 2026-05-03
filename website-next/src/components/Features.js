export default function Features() {
  return (
    <section className="features" id="features">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">PLATFORM CAPABILITIES</span>
          <h2 className="section-title">Everything You Need for<br /><span className="gradient-text">Incident Intelligence</span></h2>
          <p className="section-subtitle">From detection to resolution, SentinelFlow handles the complete incident lifecycle with AI-powered automation.</p>
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
            <p>Rule-based AI engine analyzes incidents, determines root cause, assigns severity, and calculates business impact automatically.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="200">
            <div className="feature-icon feature-icon-green">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            </div>
            <h3>Self-Healing Engine</h3>
            <p>Automated remediation that retries transient failures, resets credentials, and restarts stalled integrations without human intervention.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="300">
            <div className="feature-icon feature-icon-orange">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
            </div>
            <h3>Smart Alerting</h3>
            <p>Configurable notification rules that escalate to the right team via email, Slack, or webhook based on severity and business impact.</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="400">
            <div className="feature-icon feature-icon-pink">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>
            </div>
            <h3>Observability Dashboard</h3>
            <p>Real-time system health monitoring with error tracking, retry counts, and a global health indicator (Healthy / Degraded / Critical).</p>
          </div>
          <div className="feature-card" data-aos="fade-up" data-aos-delay="500">
            <div className="feature-icon feature-icon-cyan">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            </div>
            <h3>Enterprise Security</h3>
            <p>Multi-tenant data isolation, CRUD/FLS enforcement, API rate limiting, and feature flags for controlled rollouts across your org.</p>
          </div>
        </div>
      </div>
    </section>
  );
}
