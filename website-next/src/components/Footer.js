'use client';
import Link from 'next/link';
import Image from 'next/image';
import { useState } from 'react';

export default function Footer() {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <>
      <footer style={{ borderTop: '1px solid var(--border-color)', padding: '24px 0', background: 'var(--bg-primary)', marginTop: 'auto' }}>
        <div className="container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
            <img src="/assets/logo.svg" alt="SentinelFlow Logo" style={{ width: '20px', height: '20px' }} />
            <span>Copyright © 2026 TomCodeX Inc. All rights reserved.</span>
          </div>

          <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginBottom: '8px', flexWrap: 'wrap' }}>
            <Link href="/about" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>About Us</Link>
            <span>|</span>
            <Link href="/careers" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Careers</Link>
            <span>|</span>
            <Link href="/blog" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Blog</Link>
            <span>|</span>
            <Link href="/contact" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Contact</Link>
            <span>|</span>
            <Link href="#" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Privacy Policy</Link>
            <span>|</span>
            <Link href="#" style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Terms of Use</Link>
            <span>|</span>
            <button 
              onClick={() => setIsModalOpen(true)}
              style={{ background: 'none', border: 'none', color: '#00d2ff', textDecoration: 'none', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.8rem', padding: 0 }}
            >
              All Topics 
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"/></svg>
            </button>
          </div>

          <div style={{ marginBottom: '8px' }}>
            United States
          </div>

        </div>
      </footer>

      {isModalOpen && (
        <div style={{ position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', background: 'rgba(0,0,0,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 2000, backdropFilter: 'blur(4px)' }} onClick={() => setIsModalOpen(false)}>
          <div style={{ maxWidth: '800px', width: '90%', background: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '12px', padding: '32px', position: 'relative', maxHeight: '90vh', overflowY: 'auto' }} onClick={e => e.stopPropagation()}>
            <button onClick={() => setIsModalOpen(false)} aria-label="Close modal" style={{ position: 'absolute', top: '16px', right: '16px', background: 'none', border: 'none', fontSize: '28px', color: 'var(--text-secondary)', cursor: 'pointer' }}>&times;</button>
            <h2 style={{ marginBottom: '32px', fontSize: '1.8rem', textAlign: 'center', background: 'linear-gradient(90deg, #fff, #a8a8a8)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>Information & Topics</h2>
            
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '32px' }}>
              <div>
                <h4 style={{ color: 'var(--text-primary)', marginBottom: '16px', fontSize: '1.1rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>Product</h4>
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <li><Link href="/#features" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Features</Link></li>
                  <li><Link href="/#pricing" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Pricing</Link></li>
                  <li><Link href="/#architecture" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Architecture</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Changelog</Link></li>
                </ul>
              </div>
              
              <div>
                <h4 style={{ color: 'var(--text-primary)', marginBottom: '16px', fontSize: '1.1rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>Company</h4>
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <li><Link href="/about" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>About Us</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Our Mission</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Leadership</Link></li>
                  <li><Link href="/careers" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Careers</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Customers</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Partners</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Newsroom</Link></li>
                  <li><Link href="/blog" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Blog</Link></li>
                  <li><Link href="/contact" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Contact</Link></li>
                </ul>
              </div>

              <div>
                <h4 style={{ color: 'var(--text-primary)', marginBottom: '16px', fontSize: '1.1rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '8px' }}>Legal</h4>
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Privacy Policy</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Terms of Service</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>Security</Link></li>
                  <li><Link href="#" onClick={() => setIsModalOpen(false)} style={{ color: 'var(--text-secondary)', textDecoration: 'none' }}>GDPR</Link></li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
