'use client';
import { useState, useEffect } from 'react';
import Image from 'next/image';
import Link from 'next/link';

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
        <Link href="/" className="nav-brand">
          <Image src="/assets/logo.svg" alt="SentinelFlow Logo" width={36} height={36} className="nav-logo" />
          <span className="nav-brand-text">SentinelFlow</span>
        </Link>
        
        <div className={`nav-links ${mobileMenuOpen ? 'active' : ''}`} id="navLinks">
          <Link href="/products" onClick={() => setMobileMenuOpen(false)}>Products</Link>
          <Link href="/#features" onClick={() => setMobileMenuOpen(false)}>Features</Link>
          <Link href="/#how-it-works" onClick={() => setMobileMenuOpen(false)}>How It Works</Link>
          <Link href="/#architecture" onClick={() => setMobileMenuOpen(false)}>Architecture</Link>
          <Link href="/#pricing" onClick={() => setMobileMenuOpen(false)}>Pricing</Link>
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
