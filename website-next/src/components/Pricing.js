'use client';

export default function Pricing({ onOpenModal }) {
  return (
    <section className="pricing" id="pricing">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">PRICING</span>
          <h2 className="section-title">Simple, Transparent <span className="gradient-text">Pricing</span></h2>
          <p className="section-subtitle">Start free. Scale as you grow. No hidden fees.</p>
        </div>
        <div className="pricing-grid">
          <div className="pricing-card">
            <div className="pricing-tier">Starter</div>
            <div className="pricing-price">
              <span className="price-currency">$</span>
              <span className="price-amount">0</span>
              <span className="price-period">/month</span>
            </div>
            <p className="pricing-desc">Perfect for small teams getting started with incident management.</p>
            <ul className="pricing-features">
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Up to 100 incidents/month</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Real-time detection</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Basic alerting</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Community support</li>
            </ul>
            <button className="btn btn-outline btn-block" onClick={() => onOpenModal('Starter')}>Get Started Free</button>
          </div>
          
          <div className="pricing-card pricing-card-featured">
            <div className="pricing-badge">MOST POPULAR</div>
            <div className="pricing-tier">Professional</div>
            <div className="pricing-price">
              <span className="price-currency">$</span>
              <span className="price-amount">149</span>
              <span className="price-period">/month</span>
            </div>
            <p className="pricing-desc">For growing teams that need AI-powered automation and self-healing.</p>
            <ul className="pricing-features">
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Unlimited incidents</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> AI classification engine</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Self-healing automation</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Observability dashboard</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Priority support</li>
            </ul>
            <button className="btn btn-primary btn-block" onClick={() => onOpenModal('Professional')}>Start 14-Day Trial</button>
          </div>
          
          <div className="pricing-card">
            <div className="pricing-tier">Enterprise</div>
            <div className="pricing-price">
              <span className="price-currency"></span>
              <span className="price-amount">Custom</span>
              <span className="price-period"></span>
            </div>
            <p className="pricing-desc">For large organizations needing full multi-tenant control and compliance.</p>
            <ul className="pricing-features">
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Everything in Professional</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Multi-tenant isolation</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Feature flags per tenant</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> API rate limiting</li>
              <li><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="3"><polyline points="20 6 9 17 4 12"/></svg> Dedicated account manager</li>
            </ul>
            <button className="btn btn-outline btn-block" onClick={() => onOpenModal('Enterprise')}>Contact Sales</button>
          </div>
        </div>
      </div>
    </section>
  );
}
