import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function AboutPage() {
  return (
    <>
      <Navbar />
      <main style={{ paddingTop: '120px', paddingBottom: '120px', minHeight: '100vh' }}>
        <div className="container">
          <div className="section-header" style={{ textAlign: 'left', maxWidth: '800px', margin: '0 auto' }}>
            <h1 className="section-title">About Tomcodex</h1>
            <div style={{ marginTop: '32px', fontSize: '1.2rem', color: 'var(--text-secondary)', lineHeight: '1.8' }}>
              <p style={{ marginBottom: '24px' }}>
                Tomcodex is a modern software company focused on building intelligent, reliable systems on the Salesforce platform.
              </p>
              <p style={{ marginBottom: '24px' }}>
                We design products that go beyond traditional tools — transforming complex workflows into autonomous, self-healing systems and execution-driven environments.
              </p>
              <p>
                Our work spans reliability engineering, system intelligence, and high-performance execution tools for modern developers and enterprises.
              </p>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
