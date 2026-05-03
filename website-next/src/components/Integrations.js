export default function Integrations() {
  return (
    <section className="integrations-section" id="integrations">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">INTEGRATES WITH</span>
          <h2 className="section-title">Powered by <span className="gradient-text">Enterprise-Grade Integrations</span></h2>
          <p className="section-subtitle">Seamlessly integrates with the tools and platforms you already use.</p>
        </div>
        <div className="integrations-grid">
          {/* Salesforce */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 100 70" width="72" height="50" xmlns="http://www.w3.org/2000/svg">
                <path d="M72,24 c-2,-10 -15,-15 -25,-6 c-5,-6 -15,-7 -20,-2 c-8,-2 -15,4 -15,12 c-8,2 -12,12 -5,20 c2,3 6,4 10,4 h50 c6,0 12,-3 14,-8 c3,-6 1,-15 -6,-17 c0,-2 -1,-2 -3,-3 z" fill="#00a1e0" />
              </svg>
            </div>
            <h4 className="integration-name">Salesforce</h4>
            <p className="integration-desc">CRM Platform</p>
          </div>
          {/* Stripe */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 100 40" width="76" height="30" xmlns="http://www.w3.org/2000/svg">
                <text x="0" y="32" fontFamily="Arial, sans-serif" fontWeight="900" fontSize="34" fill="#635bff" letterSpacing="-1">stripe</text>
              </svg>
            </div>
            <h4 className="integration-name">Stripe</h4>
            <p className="integration-desc">Payment Processing</p>
          </div>
          {/* SAP */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 100 50" width="64" height="32" xmlns="http://www.w3.org/2000/svg">
                <polygon points="10,0 90,0 100,50 0,50" fill="#008fd3" />
                <text x="50" y="36" textAnchor="middle" fontFamily="Arial, sans-serif" fontWeight="800" fontSize="28" fill="#ffffff">SAP</text>
              </svg>
            </div>
            <h4 className="integration-name">SAP</h4>
            <p className="integration-desc">Enterprise Systems</p>
          </div>
          {/* Auth0 */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 160 40" width="110" height="28" xmlns="http://www.w3.org/2000/svg">
                <path d="M 16 0 L 48 0 L 56 24 L 32 40 L 8 24 Z" fill="#eb5424" />
                <polygon points="32,8 36,20 48,20 38,26 42,36 32,28 22,36 26,26 16,20 28,20" fill="var(--bg-card)"/>
                <text x="64" y="28" fontFamily="Arial, sans-serif" fontWeight="800" fontSize="28" fill="white" letterSpacing="-0.5">Auth0</text>
              </svg>
            </div>
            <h4 className="integration-name">Auth0</h4>
            <p className="integration-desc">Authentication</p>
          </div>
          {/* REST API */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 100 100" width="70" height="70" xmlns="http://www.w3.org/2000/svg">
                <path d="M 30 65 A 15 15 0 0 1 30 35 A 20 20 0 0 1 65 25 A 22 22 0 0 1 85 55 A 12 12 0 0 1 75 65 Z" fill="none" stroke="#24d48a" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"/>
                <text x="52" y="56" textAnchor="middle" fontFamily="monospace" fontWeight="800" fontSize="28" fill="#24d48a">{`{}`}</text>
              </svg>
            </div>
            <h4 className="integration-name">REST API</h4>
            <p className="integration-desc">API Integration</p>
          </div>
          {/* Webhooks */}
          <div className="integration-card">
            <div className="integration-logo">
              <svg viewBox="0 0 100 100" width="64" height="64" xmlns="http://www.w3.org/2000/svg">
                <line x1="50" y1="20" x2="25" y2="65" stroke="#a855f7" strokeWidth="6"/>
                <line x1="25" y1="65" x2="75" y2="65" stroke="#a855f7" strokeWidth="6"/>
                <line x1="75" y1="65" x2="50" y2="20" stroke="#a855f7" strokeWidth="6"/>
                <circle cx="50" cy="20" r="12" fill="var(--bg-card)" stroke="#a855f7" strokeWidth="6" />
                <circle cx="25" cy="65" r="12" fill="var(--bg-card)" stroke="#a855f7" strokeWidth="6" />
                <circle cx="75" cy="65" r="12" fill="var(--bg-card)" stroke="#a855f7" strokeWidth="6" />
                <circle cx="50" cy="20" r="4" fill="#a855f7" />
                <circle cx="25" cy="65" r="4" fill="#a855f7" />
                <circle cx="75" cy="65" r="4" fill="#a855f7" />
              </svg>
            </div>
            <h4 className="integration-name">Webhooks</h4>
            <p className="integration-desc">Event Notifications</p>
          </div>
        </div>
      </div>
    </section>
  );
}
