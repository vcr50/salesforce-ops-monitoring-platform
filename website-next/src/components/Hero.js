'use client';
import { useEffect, useState, useRef } from 'react';
import Image from 'next/image';

const CountUp = ({ end, suffix = '', duration = 2000 }) => {
  const [count, setCount] = useState(0);
  const elementRef = useRef(null);

  useEffect(() => {
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        let startTimestamp = null;
        const step = (timestamp) => {
          if (!startTimestamp) startTimestamp = timestamp;
          const progress = Math.min((timestamp - startTimestamp) / duration, 1);
          setCount(Math.floor(progress * end));
          if (progress < 1) {
            window.requestAnimationFrame(step);
          }
        };
        window.requestAnimationFrame(step);
        observer.disconnect();
      }
    });

    if (elementRef.current) {
      observer.observe(elementRef.current);
    }

    return () => observer.disconnect();
  }, [end, duration]);

  // Adjust display for floats
  const displayValue = end % 1 !== 0 
    ? (count * (end / Math.floor(end))).toFixed(1) 
    : count;

  return (
    <span ref={elementRef}>
      {displayValue === end.toString() ? end : displayValue}{suffix}
    </span>
  );
};

export default function Hero() {
  return (
    <section className="hero" id="hero">
      <div className="hero-bg-effects">
        <div className="hero-orb hero-orb-1"></div>
        <div className="hero-orb hero-orb-2"></div>
        <div className="hero-orb hero-orb-3"></div>
        <div className="hero-grid"></div>
      </div>
      <div className="container hero-content">
        <div className="hero-badge">
          <span className="badge-dot"></span>
          AgentExchange v3.0 - Published by Tomcodex
        </div>
        <h1 className="hero-title">
          Detect. Analyze.<br />
          <span className="gradient-text">Auto-Heal.</span>
        </h1>
        <p className="hero-subtitle">
          SentinelFlow is an AI-powered Salesforce operations platform that detects incidents,
          predicts risk, recommends runbooks, auto-heals approved failures, and learns from
          every recovery outcome.
        </p>
        <div className="hero-cta">
          <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000c4aTQAQ" target="_blank" rel="noopener noreferrer" className="btn btn-primary btn-lg">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
            INSTALL IN SALESFORCE
          </a>
          <a href="#demo" className="btn btn-outline btn-lg">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
            WATCH DEMO
          </a>
        </div>
        <div style={{ marginTop: '2rem', color: '#8b9bb4', fontSize: '0.9rem', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', fontFamily: 'monospace' }}>
          v3.0 Package ID: <span style={{ padding: '4px 8px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '4px', color: '#00e5ff' }}>04tdL000000c4aTQAQ</span>
        </div>
      </div>
      <div className="hero-dashboard-preview">
        <div className="dashboard-glow"></div>
        <Image 
          src="/assets/dashboard-preview.png" 
          alt="SentinelFlow Dashboard" 
          width={1000} 
          height={600} 
          className="dashboard-img" 
          priority
        />
      </div>
    </section>
  );
}
