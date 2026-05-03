import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import Link from 'next/link';

export default function BlogPage() {
  return (
    <>
      <Navbar />
      <main style={{ paddingTop: '120px', paddingBottom: '120px', minHeight: '100vh' }}>
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Blog</span>
            <h1 className="section-title">Insights & Engineering</h1>
            <p className="section-subtitle">
              Read the latest news, product updates, and deep dives from the SentinelFlow engineering team.
            </p>
          </div>

          <div className="features-grid" style={{ marginTop: '64px' }}>
            <div className="feature-card">
              <span className="section-tag" style={{ color: 'var(--blue)' }}>Product Update</span>
              <h3 style={{ marginTop: '12px' }}>Introducing the Agentforce Integration</h3>
              <p style={{ marginBottom: '24px' }}>Learn how we are deeply integrating with Salesforce's Agentforce to bring autonomous healing to the enterprise.</p>
              <Link href="#" className="btn-ghost" style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Read More &rarr;</Link>
            </div>
            
            <div className="feature-card">
              <span className="section-tag" style={{ color: 'var(--green)' }}>Engineering</span>
              <h3 style={{ marginTop: '12px' }}>Scaling the Incident Webhook Processing</h3>
              <p style={{ marginBottom: '24px' }}>A deep dive into how we use Apex REST and queueables to process 10k+ incidents per minute securely.</p>
              <Link href="#" className="btn-ghost" style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Read More &rarr;</Link>
            </div>
            
            <div className="feature-card">
              <span className="section-tag" style={{ color: 'var(--orange)' }}>Best Practices</span>
              <h3 style={{ marginTop: '12px' }}>5 Tips for Auto-Healing Microservices</h3>
              <p style={{ marginBottom: '24px' }}>Discover the critical strategies and rules for setting up safe and effective auto-remediation policies.</p>
              <Link href="#" className="btn-ghost" style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Read More &rarr;</Link>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
