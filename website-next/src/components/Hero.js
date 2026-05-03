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
          Enterprise-Grade Incident Intelligence
        </div>
        <h1 className="hero-title">
          Detect. Analyze.<br />
          <span className="gradient-text">Auto-Heal.</span>
        </h1>
        <p className="hero-subtitle">
          SentinelFlow is an AI-powered platform that monitors your integrations, 
          classifies incidents in real-time, and automatically resolves production 
          issues before they impact your revenue.
        </p>
        <div className="hero-cta">
          <a href="#pricing" className="btn btn-primary btn-lg">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
            Start Free Trial
          </a>
          <a href="#demo" className="btn btn-outline btn-lg">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
            Watch Demo
          </a>
        </div>
        <div className="hero-stats">
          <div className="hero-stat">
            <span className="hero-stat-value"><CountUp end={99.9} /></span><span className="hero-stat-suffix">%</span>
            <span className="hero-stat-label">Uptime SLA</span>
          </div>
          <div className="hero-stat-divider"></div>
          <div className="hero-stat">
            <span className="hero-stat-value"><CountUp end={85} /></span><span className="hero-stat-suffix">%</span>
            <span className="hero-stat-label">Faster Resolution</span>
          </div>
          <div className="hero-stat-divider"></div>
          <div className="hero-stat">
            <span className="hero-stat-value"><CountUp end={10} /></span><span className="hero-stat-suffix">+</span>
            <span className="hero-stat-label">Early Adopters</span>
          </div>
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
