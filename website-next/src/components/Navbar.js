'use client';
import { useState, useEffect } from 'react';
import Image from 'next/image';

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <nav className={`navbar ${scrolled ? 'scrolled' : ''}`} id="navbar">
      <div className="nav-container">
        <a href="#" className="nav-brand">
          <Image src="/assets/logo.svg" alt="SentinelFlow Logo" width={36} height={36} className="nav-logo" />
          <span className="nav-brand-text">SentinelFlow</span>
        </a>
        
        <div className={`nav-links ${mobileMenuOpen ? 'active' : ''}`} id="navLinks">
          <a href="#features" onClick={() => setMobileMenuOpen(false)}>Features</a>
          <a href="#how-it-works" onClick={() => setMobileMenuOpen(false)}>How It Works</a>
          <a href="#architecture" onClick={() => setMobileMenuOpen(false)}>Architecture</a>
          <a href="#pricing" onClick={() => setMobileMenuOpen(false)}>Pricing</a>
        </div>
        
        <div className="nav-actions">
          <a href="#pricing" className="btn btn-ghost">Start Free Trial</a>
          <a href="#demo" className="btn btn-primary">Book a Demo</a>
        </div>
        
        <button 
          className="nav-toggle" 
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          aria-label="Toggle menu"
        >
          <span></span><span></span><span></span>
        </button>
      </div>
    </nav>
  );
}
