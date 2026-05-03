'use client';

export default function CTA({ onOpenModal }) {
  return (
    <section className="cta" id="demo">
      <div className="cta-glow"></div>
      <div className="container">
        <h2 className="cta-title">Ready to Eliminate Downtime?</h2>
        <p className="cta-subtitle">Be among the first teams to experience AI-powered incident resolution on Salesforce.</p>
        <div className="cta-actions">
          <button className="btn btn-primary btn-lg" onClick={() => onOpenModal('Professional')}>Start Your Free Trial</button>
          <button className="btn btn-ghost btn-lg" onClick={() => onOpenModal('Demo')}>Schedule a Demo →</button>
        </div>
      </div>
    </section>
  );
}
