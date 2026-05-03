'use client';
import { useState } from 'react';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function ContactPage() {
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    setSubmitted(true);
  };

  return (
    <>
      <Navbar />
      <main style={{ paddingTop: '120px', paddingBottom: '120px', minHeight: '100vh' }}>
        <div className="container">
          <div className="section-header">
            <span className="section-tag">Contact Us</span>
            <h1 className="section-title">Get in Touch</h1>
            <p className="section-subtitle">
              Have questions about SentinelFlow? Our team is here to help you build a more reliable enterprise.
            </p>
          </div>

          <div style={{ maxWidth: '600px', margin: '64px auto 0' }} className="feature-card">
            {submitted ? (
              <div style={{ textAlign: 'center', padding: '40px 0' }}>
                <div className="feature-icon feature-icon-green" style={{ margin: '0 auto 20px' }}>
                  <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <h3>Message Sent Successfully!</h3>
                <p style={{ color: 'var(--text-secondary)', marginTop: '10px' }}>We will get back to you within 24 hours.</p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>Name</label>
                  <input type="text" required style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)', background: 'var(--bg-secondary)', color: 'var(--text-primary)', outline: 'none' }} placeholder="John Doe" />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>Work Email</label>
                  <input type="email" required style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)', background: 'var(--bg-secondary)', color: 'var(--text-primary)', outline: 'none' }} placeholder="john@company.com" />
                </div>
                <div>
                  <label style={{ display: 'block', marginBottom: '8px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>Message</label>
                  <textarea required rows={5} style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-color)', background: 'var(--bg-secondary)', color: 'var(--text-primary)', outline: 'none', resize: 'vertical' }} placeholder="How can we help?"></textarea>
                </div>
                <button type="submit" className="btn btn-primary btn-block" style={{ marginTop: '10px' }}>Send Message</button>
              </form>
            )}
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
