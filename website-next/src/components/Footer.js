import Image from 'next/image';

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-brand">
            <div className="footer-logo">
              <Image src="/assets/logo.svg" alt="SentinelFlow" width={36} height={36} className="nav-logo" />
              <span className="nav-brand-text">SentinelFlow</span>
            </div>
            <p className="footer-tagline">AI-powered incident intelligence for the modern enterprise.</p>
            <p className="footer-copyright">© 2026 TomCodeX Inc. All rights reserved.</p>
          </div>
          <div className="footer-links">
            <h4>Product</h4>
            <a href="#features">Features</a>
            <a href="#pricing">Pricing</a>
            <a href="#architecture">Architecture</a>
            <a href="#">Changelog</a>
          </div>
          <div className="footer-links">
            <h4>Company</h4>
            <a href="#">About</a>
            <a href="#">Careers</a>
            <a href="#">Blog</a>
            <a href="#">Contact</a>
          </div>
          <div className="footer-links">
            <h4>Legal</h4>
            <a href="#">Privacy Policy</a>
            <a href="#">Terms of Service</a>
            <a href="#">Security</a>
            <a href="#">GDPR</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
