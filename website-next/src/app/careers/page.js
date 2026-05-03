import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import Link from 'next/link';

export default function CareersPage() {
  return (
    <>
      <Navbar />
      <main style={{ paddingTop: '120px', paddingBottom: '120px', minHeight: '100vh' }}>
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Careers</span>
            <h1 className="section-title">Join the SentinelFlow Team</h1>
            <p className="section-subtitle">
              Help us build the future of incident intelligence. We are always looking for passionate, driven individuals to join our remote-first team.
            </p>
          </div>

          <div style={{ maxWidth: '800px', margin: '64px auto 0' }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '24px' }}>Open Positions</h2>
            
            <div className="feature-card" style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h3 style={{ marginBottom: '8px' }}>Senior Machine Learning Engineer</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Remote - Full Time</p>
              </div>
              <Link href="/contact" className="btn btn-outline">Apply Now</Link>
            </div>

            <div className="feature-card" style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h3 style={{ marginBottom: '8px' }}>Salesforce Architect</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Remote - Full Time</p>
              </div>
              <Link href="/contact" className="btn btn-outline">Apply Now</Link>
            </div>

            <div className="feature-card" style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h3 style={{ marginBottom: '8px' }}>Developer Advocate</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Remote - Full Time</p>
              </div>
              <Link href="/contact" className="btn btn-outline">Apply Now</Link>
            </div>

          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
