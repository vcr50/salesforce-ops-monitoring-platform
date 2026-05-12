'use client';

export default function AgentExchangePromo({ onOpenModal }) {
  return (
    <section className="promo-section" id="agentexchange">
      <div className="container promo-container">
        <div className="promo-content">
          <div className="promo-badge">
            <span className="badge-dot"></span> AgentExchange Live
          </div>
          <h2 className="promo-title">SentinelFlow is AgentExchange Ready</h2>
          <p className="promo-subtitle">
            Experience the full power of SentinelFlow 2.6, published by Tomcodex, with our 2GP package.
            Install memory, prediction intelligence, adaptive runbooks, learning loops, and enterprise isolation.
          </p>
          <div className="promo-actions">
            <button className="btn btn-primary btn-lg" onClick={() => onOpenModal('Free Trial')}>Start Free Trial</button>
            <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000aQVRQA2" target="_blank" rel="noopener noreferrer" className="btn btn-outline btn-lg">Get Package (2GP)</a>
          </div>
        </div>
        <div className="promo-visual">
          <div className="promo-card">
            {/* The user will upload agentexchange-logo.png to public folder */}
            <img src="/agentexchange-logo.png" alt="Salesforce AgentExchange" className="promo-logo" onError={(e) => e.target.style.display = 'none'} />
            <div className="promo-stats">
              <div className="promo-stat">
                <span className="promo-stat-val">v2.6</span>
                <span className="promo-stat-label">Version</span>
              </div>
              <div className="promo-stat">
                <span className="promo-stat-val">2GP</span>
                <span className="promo-stat-label">Package</span>
              </div>
              <div className="promo-stat">
                <span className="promo-stat-val">SSO</span>
                <span className="promo-stat-label">Enabled</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
