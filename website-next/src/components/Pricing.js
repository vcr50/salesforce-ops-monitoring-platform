'use client';

const CheckIcon = ({ blue }) => (
  <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }}>
    <circle
      cx="9" cy="9" r="8"
      fill={blue ? 'rgba(59,130,246,0.10)' : 'none'}
      stroke={blue ? 'rgba(59,130,246,0.45)' : 'rgba(99,120,180,0.5)'}
      strokeWidth="1.5"
    />
    <polyline
      points="5.5,9.5 7.5,11.5 12.5,6.5"
      fill="none"
      stroke={blue ? '#60a5fa' : 'rgba(99,120,180,0.7)'}
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export default function Pricing({ onOpenModal }) {
  return (
    <section className="sf-pricing" id="pricing">
      <div className="container">

        {/* Header */}
        <div className="sf-pricing__header">
          <span className="sf-pricing__eyebrow">Pricing</span>
          <h2 className="sf-pricing__title">
            Plans built for<br />
            <span className="sf-pricing__title-accent">every stage of growth</span>
          </h2>
          <p className="sf-pricing__subtitle">
            Start free, scale when you&apos;re ready. No hidden fees, no lock-in.
          </p>
        </div>

        {/* Cards */}
        <div className="sf-pricing__grid">

          {/* Starter */}
          <article className="sf-card">
            <p className="sf-card__tier">Starter</p>
            <div className="sf-card__price-row">
              <span className="sf-card__price">$0</span>
              <span className="sf-card__period">/ month</span>
            </div>
            <p className="sf-card__desc">
              Perfect for individuals and small teams getting started.
            </p>
            <hr className="sf-card__divider" />
            <p className="sf-card__feature-label">What&apos;s included</p>
            <ul className="sf-card__features">
              <li><CheckIcon /><span>Up to 100 incidents / month</span></li>
              <li><CheckIcon /><span>Real-time detection</span></li>
              <li><CheckIcon /><span>Basic alerting</span></li>
              <li><CheckIcon /><span>Community support</span></li>
            </ul>
            <button
              id="btn-starter"
              className="sf-btn sf-btn--outline"
              onClick={() => onOpenModal('Starter')}
            >
              Get Started Free
            </button>
          </article>

          {/* Professional */}
          <article className="sf-card sf-card--highlight">
            <span className="sf-card__badge">
              <span className="sf-card__badge-dot" aria-hidden="true" />
              Most Popular
            </span>
            <p className="sf-card__tier">Professional</p>
            <div className="sf-card__price-row">
              <span className="sf-card__price">$29</span>
              <span className="sf-card__period">/ month</span>
              <span className="sf-card__strike" aria-label="Regular price $149">$149</span>
            </div>
            <span className="sf-card__price-label">Early Access Pricing</span>
            <p className="sf-card__desc">
              For growing teams that need AppExchange v2.6 automation, memory, prediction, and self-healing.
            </p>
            <hr className="sf-card__divider" />
            <p className="sf-card__feature-label">Everything in Starter, plus</p>
            <ul className="sf-card__features">
              <li><CheckIcon blue /><span>Unlimited incidents</span></li>
              <li><CheckIcon blue /><span>AI classification + incident memory</span></li>
              <li><CheckIcon blue /><span>Adaptive auto-heal runbooks</span></li>
              <li><CheckIcon blue /><span>Prediction V2 risk scoring</span></li>
              <li><CheckIcon blue /><span>Dashboard V2 + learning quality</span></li>
            </ul>
            <button
              id="btn-professional"
              className="sf-btn sf-btn--primary"
              onClick={() => onOpenModal('Professional')}
            >
              Start 14-Day Trial
            </button>
          </article>

          {/* Enterprise */}
          <article className="sf-card">
            <p className="sf-card__tier">Enterprise</p>
            <div className="sf-card__price-row">
              <span className="sf-card__price sf-card__price--custom">Custom</span>
            </div>
            <p className="sf-card__desc">
              For organizations needing full control, security review support, and enterprise scale.
            </p>
            <hr className="sf-card__divider" />
            <p className="sf-card__feature-label">Everything in Professional, plus</p>
            <ul className="sf-card__features">
              <li><CheckIcon /><span>Tenant-isolated memory and RLS</span></li>
              <li><CheckIcon /><span>Reliability simulation suite</span></li>
              <li><CheckIcon /><span>API rate limits and circuit breakers</span></li>
              <li><CheckIcon /><span>Security review and packaging support</span></li>
            </ul>
            <button
              id="btn-enterprise"
              className="sf-btn sf-btn--ghost"
              onClick={() => onOpenModal('Enterprise')}
            >
              Contact Sales
            </button>
          </article>

        </div>{/* /grid */}

        <p className="sf-pricing__footnote">
          All plans include AppExchange v2.6 package metadata, Tomcodex publisher support, SOC 2-ready logging design, and 99.9% uptime SLA targets.
        </p>
      </div>

      {/* Scoped styles */}
      <style>{`
        /* ── Section ── */
        .sf-pricing {
          padding: 120px 0;
          background: var(--bg-secondary);
          position: relative;
        }
        .sf-pricing::before {
          content: '';
          position: absolute;
          inset: 0;
          background:
            radial-gradient(ellipse 60% 35% at 50% 0%, rgba(37,99,235,0.10) 0%, transparent 65%),
            radial-gradient(ellipse 35% 25% at 8% 80%, rgba(29,78,216,0.06) 0%, transparent 55%),
            radial-gradient(ellipse 35% 25% at 92% 70%, rgba(59,130,246,0.05) 0%, transparent 55%);
          pointer-events: none;
        }

        /* ── Header ── */
        .sf-pricing__header {
          text-align: center;
          margin-bottom: 64px;
        }
        .sf-pricing__eyebrow {
          display: inline-block;
          font-size: 11px;
          font-weight: 600;
          letter-spacing: 0.14em;
          text-transform: uppercase;
          color: #60a5fa;
          background: rgba(59,130,246,0.08);
          border: 1px solid rgba(59,130,246,0.2);
          border-radius: 100px;
          padding: 5px 14px;
          margin-bottom: 22px;
        }
        .sf-pricing__title {
          font-size: clamp(28px, 4vw, 46px);
          font-weight: 700;
          letter-spacing: -0.03em;
          line-height: 1.12;
          color: var(--text-primary);
          margin-bottom: 16px;
        }
        .sf-pricing__title-accent {
          background: linear-gradient(135deg, #93c5fd 0%, #3b82f6 50%, #818cf8 100%);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          background-clip: text;
        }
        .sf-pricing__subtitle {
          font-size: 16px;
          color: var(--text-secondary);
          line-height: 1.65;
          max-width: 440px;
          margin: 0 auto;
        }

        /* ── Grid ── */
        .sf-pricing__grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 20px;
          align-items: stretch;
        }

        /* ── Card ── */
        .sf-card {
          position: relative;
          background: rgba(12,17,32,0.85);
          border: 1px solid rgba(99,120,180,0.12);
          border-radius: 20px;
          padding: 36px 32px 40px;
          display: flex;
          flex-direction: column;
          backdrop-filter: blur(14px);
          -webkit-backdrop-filter: blur(14px);
          transition: transform 0.3s cubic-bezier(.25,.46,.45,.94),
                      border-color 0.3s ease,
                      box-shadow 0.3s ease;
          cursor: default;
        }
        .sf-card:hover {
          transform: translateY(-6px) scale(1.015);
          border-color: rgba(99,120,200,0.28);
          box-shadow: 0 24px 60px rgba(0,0,0,0.35), 0 1px 0 rgba(255,255,255,0.04) inset;
        }

        /* Highlighted */
        .sf-card--highlight {
          background: rgba(14,22,48,0.9);
          border-color: rgba(59,130,246,0.35);
          box-shadow:
            0 0 0 1px rgba(59,130,246,0.18),
            0 20px 50px rgba(37,99,235,0.14),
            0 1px 0 rgba(255,255,255,0.06) inset;
        }
        .sf-card--highlight:hover {
          border-color: rgba(59,130,246,0.55);
          box-shadow:
            0 0 0 1px rgba(59,130,246,0.30),
            0 28px 70px rgba(37,99,235,0.22),
            0 1px 0 rgba(255,255,255,0.06) inset;
        }
        .sf-card--highlight::before {
          content: '';
          position: absolute;
          top: 0;
          left: 50%;
          transform: translateX(-50%);
          width: 60%;
          height: 1px;
          background: linear-gradient(90deg, transparent, rgba(99,160,255,0.7), transparent);
          border-radius: 100%;
        }

        /* Badge */
        .sf-card__badge {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          font-size: 11px;
          font-weight: 600;
          letter-spacing: 0.06em;
          text-transform: uppercase;
          color: #93c5fd;
          background: rgba(59,130,246,0.12);
          border: 1px solid rgba(59,130,246,0.25);
          border-radius: 100px;
          padding: 4px 11px;
          margin-bottom: 20px;
          width: fit-content;
        }
        .sf-card__badge-dot {
          display: block;
          width: 6px;
          height: 6px;
          border-radius: 50%;
          background: #60a5fa;
          box-shadow: 0 0 6px #60a5fa;
        }

        /* Tier / plan name */
        .sf-card__tier {
          font-size: 13px;
          font-weight: 600;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: var(--text-secondary);
          margin-bottom: 14px;
        }

        /* Price */
        .sf-card__price-row {
          display: flex;
          align-items: flex-end;
          gap: 8px;
          flex-wrap: wrap;
          margin-bottom: 6px;
        }
        .sf-card__price {
          font-size: 46px;
          font-weight: 700;
          letter-spacing: -0.04em;
          line-height: 1;
          color: var(--text-primary);
        }
        .sf-card__price--custom {
          font-size: 34px;
        }
        .sf-card__period {
          font-size: 14px;
          color: var(--text-muted);
          margin-bottom: 5px;
        }
        .sf-card__strike {
          font-size: 15px;
          font-weight: 500;
          color: var(--text-muted);
          text-decoration: line-through;
          text-decoration-color: rgba(139,156,200,0.45);
          margin-bottom: 5px;
        }
        .sf-card__price-label {
          display: inline-block;
          font-size: 11.5px;
          font-weight: 500;
          color: #60a5fa;
          background: rgba(59,130,246,0.08);
          border: 1px solid rgba(59,130,246,0.18);
          border-radius: 6px;
          padding: 3px 8px;
          margin-bottom: 16px;
        }

        /* Description */
        .sf-card__desc {
          font-size: 13.5px;
          color: var(--text-secondary);
          line-height: 1.6;
          margin-bottom: 24px;
        }

        /* Divider */
        .sf-card__divider {
          border: none;
          border-top: 1px solid rgba(99,120,180,0.12);
          margin-bottom: 22px;
        }

        /* Features */
        .sf-card__feature-label {
          font-size: 10.5px;
          font-weight: 600;
          letter-spacing: 0.10em;
          text-transform: uppercase;
          color: var(--text-muted);
          margin-bottom: 14px;
        }
        .sf-card__features {
          list-style: none;
          display: flex;
          flex-direction: column;
          gap: 12px;
          flex: 1;
          margin-bottom: 28px;
        }
        .sf-card__features li {
          display: flex;
          align-items: flex-start;
          gap: 10px;
          font-size: 13.5px;
          color: var(--text-primary);
          line-height: 1.5;
        }

        /* Buttons */
        .sf-btn {
          display: block;
          width: 100%;
          padding: 13px 20px;
          border-radius: 10px;
          font-family: inherit;
          font-size: 14px;
          font-weight: 600;
          letter-spacing: 0.01em;
          text-align: center;
          cursor: pointer;
          border: none;
          transition: background 0.28s ease, transform 0.28s ease, box-shadow 0.28s ease;
        }
        .sf-btn--outline {
          background: transparent;
          color: var(--text-primary);
          border: 1px solid rgba(99,120,180,0.30);
        }
        .sf-btn--outline:hover {
          background: rgba(255,255,255,0.04);
          border-color: rgba(99,120,180,0.5);
          transform: translateY(-1px);
        }
        .sf-btn--primary {
          background: linear-gradient(135deg, #2563eb 0%, #3b82f6 60%, #60a5fa 100%);
          color: #ffffff;
          border: 1px solid rgba(99,160,255,0.3);
          box-shadow:
            0 0 22px rgba(37,99,235,0.42),
            0 4px 14px rgba(37,99,235,0.30),
            0 1px 0 rgba(255,255,255,0.15) inset;
        }
        .sf-btn--primary:hover {
          background: linear-gradient(135deg, #1d4ed8 0%, #2563eb 60%, #3b82f6 100%);
          box-shadow:
            0 0 32px rgba(37,99,235,0.56),
            0 6px 20px rgba(37,99,235,0.40),
            0 1px 0 rgba(255,255,255,0.15) inset;
          transform: translateY(-1px);
        }
        .sf-btn--ghost {
          background: rgba(255,255,255,0.04);
          color: var(--text-primary);
          border: 1px solid rgba(99,120,180,0.20);
        }
        .sf-btn--ghost:hover {
          background: rgba(255,255,255,0.07);
          border-color: rgba(99,120,180,0.40);
          transform: translateY(-1px);
        }

        /* Footnote */
        .sf-pricing__footnote {
          text-align: center;
          margin-top: 40px;
          font-size: 13px;
          color: var(--text-muted);
        }

        /* Responsive */
        @media (max-width: 1024px) {
          .sf-pricing__grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 640px) {
          .sf-pricing__grid { grid-template-columns: 1fr; max-width: 400px; margin: 0 auto; }
          .sf-card { padding: 28px 22px 32px; }
        }
      `}</style>
    </section>
  );
}
