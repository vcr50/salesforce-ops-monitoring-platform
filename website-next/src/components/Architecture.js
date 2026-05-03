export default function Architecture() {
  return (
    <section className="architecture" id="architecture">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">BUILT FOR SCALE</span>
          <h2 className="section-title">Enterprise-Grade <span className="gradient-text">Architecture</span></h2>
          <p className="section-subtitle">Built natively on Salesforce Platform with zero external dependencies.</p>
        </div>
        <div className="arch-grid">
          <div className="arch-card">
            <div className="arch-icon">🔒</div>
            <h4>Multi-Tenant Isolation</h4>
            <p>Each tenant&apos;s data is fully isolated via Tenant__c lookups and WITH USER_MODE enforcement.</p>
          </div>
          <div className="arch-card">
            <div className="arch-icon">⚡</div>
            <h4>Async Processing</h4>
            <p>Bulkified Queueables handle 200+ incidents per transaction without hitting governor limits.</p>
          </div>
          <div className="arch-card">
            <div className="arch-icon">🛡️</div>
            <h4>API Rate Limiting</h4>
            <p>Platform Cache-backed fixed-window rate limiter protects endpoints with HTTP 429 responses.</p>
          </div>
          <div className="arch-card">
            <div className="arch-icon">🔄</div>
            <h4>Intelligent Retries</h4>
            <p>Transient vs. permanent failure classification prevents wasted retries on unrecoverable errors.</p>
          </div>
          <div className="arch-card">
            <div className="arch-icon">🎛️</div>
            <h4>Feature Flags</h4>
            <p>Custom Metadata-driven toggles let admins enable/disable AI, Auto-Heal, or Alerting per tenant.</p>
          </div>
          <div className="arch-card">
            <div className="arch-icon">📊</div>
            <h4>Dead-Letter Logging</h4>
            <p>Every failed operation is captured in System_Log__c with full stack traces for post-mortem analysis.</p>
          </div>
        </div>
      </div>
    </section>
  );
}
