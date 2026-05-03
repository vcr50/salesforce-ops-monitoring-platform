import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function ProductsPage() {
  return (
    <>
      <Navbar />
      <main style={{ paddingTop: '120px', paddingBottom: '120px', minHeight: '100vh' }}>
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Our Products</span>
            <h1 className="section-title">Execution & Intelligence</h1>
            <p className="section-subtitle">
              High-performance tools for modern developers and enterprises.
            </p>
          </div>

          <div className="features-grid" style={{ marginTop: '64px', gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))' }}>
            
            <div className="feature-card" style={{ padding: '40px' }}>
              <div className="feature-icon feature-icon-purple" style={{ marginBottom: '24px', width: '56px', height: '56px' }}>
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm0 14a1 1 0 1 1 1-1 1 1 0 0 1-1 1zm1-5a1 1 0 0 1-2 0V7a1 1 0 0 1 2 0z"/></svg>
              </div>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '16px' }}>SentinelFlow</h3>
              <p style={{ fontSize: '1.1rem', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
                Autonomous reliability platform for Salesforce integrations.
              </p>
            </div>

            <div className="feature-card" style={{ padding: '40px' }}>
              <div className="feature-icon feature-icon-blue" style={{ marginBottom: '24px', width: '56px', height: '56px' }}>
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polygon points="12 2 2 7 12 12 22 7 12 2" /><polyline points="2 12 12 17 22 12" /><polyline points="2 17 12 22 22 17" /></svg>
              </div>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '16px' }}>VertexDB</h3>
              <p style={{ fontSize: '1.1rem', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
                Execution and intelligence workspace for planning, tracking, and system-level control.
              </p>
            </div>

          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
