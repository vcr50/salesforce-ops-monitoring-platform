export default function HowItWorks() {
  return (
    <section className="how-it-works" id="how-it-works">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">WORKFLOW</span>
          <h2 className="section-title">How SentinelFlow <span className="gradient-text">Protects You</span></h2>
          <p className="section-subtitle">From the moment an integration fails to prediction, recovery, validation, and learning.</p>
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
              <h3>Classify + Remember</h3>
              <p>The AI engine assigns severity and root cause, then checks operational memory for similar incidents and proven fixes.</p>
            </div>
          </div>
          <div className="step">
            <div className="step-number">03</div>
            <div className="step-content">
              <h3>Predict</h3>
              <p>Prediction V2 scores failure probability, deployment risk, and org stability so teams can prevent the next outage.</p>
            </div>
          </div>
          <div className="step">
            <div className="step-number">04</div>
            <div className="step-content">
              <h3>Heal + Learn</h3>
              <p>Approved runbooks execute recovery actions, validate outcomes, and feed the learning loop to improve future confidence.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
