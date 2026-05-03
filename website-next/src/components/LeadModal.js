'use client';
import { useState, useRef } from 'react';

export default function LeadModal({ isOpen, onClose, plan }) {
  const [submitted, setSubmitted] = useState(false);
  const formRef = useRef(null);
  const isProfessional = plan === 'Professional';

  if (!isOpen) return null;

  const handleSubmit = () => {
    const formData = new FormData(formRef.current);
    const email = formData.get('email')?.toString().trim();

    // We let the form naturally submit to the hidden iframe
    setTimeout(() => {
      if (isProfessional && email) {
        const checkoutUrl = new URL('/upgrade.html', window.location.origin);
        checkoutUrl.searchParams.set('plan', 'Professional');
        checkoutUrl.searchParams.set('email', email);
        checkoutUrl.searchParams.set('orgId', `web-lead:${email}`);
        window.location.assign(checkoutUrl.toString());
        return;
      }

      setSubmitted(true);
      if (formRef.current) formRef.current.reset();
    }, 500);
  };

  const handleClose = () => {
    setSubmitted(false);
    onClose();
  };

  return (
    <div className="modal-overlay active" id="modalOverlay" style={{ display: 'flex' }} onClick={handleClose}>
      <div className="modal" id="modal" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={handleClose} aria-label="Close modal">&times;</button>
        
        {!submitted ? (
          <>
            <div className="modal-icon">⚡</div>
            <h2 className="modal-title">Start Your Free Trial</h2>
            <p className="modal-desc">Enter your details and we&apos;ll get you set up in under 2 minutes.</p>
            
            <form 
              ref={formRef}
              className="modal-form" 
              action="https://webto.salesforce.com/servlet/servlet.WebToLead?encoding=UTF-8" 
              method="POST" 
              target="w2l_iframe"
              onSubmit={handleSubmit}
            >
              <input type="hidden" name="oid" value="00DdL0000053505" />
              <input type="hidden" name="retURL" value="http://localhost:3500" />
              <input type="hidden" name="lead_source" value="Website" />
              <input
                type="hidden"
                name="description"
                value={isProfessional ? 'Plan: Professional; Checkout: Pending' : `Plan: ${plan || 'Unknown'}`}
              />
              
              <div className="form-row" style={{ display: 'flex', gap: '16px' }}>
                <div className="form-group" style={{ flex: 1 }}>
                  <label htmlFor="first_name">First Name</label>
                  <input type="text" id="first_name" name="first_name" placeholder="John" required />
                </div>
                <div className="form-group" style={{ flex: 1 }}>
                  <label htmlFor="last_name">Last Name</label>
                  <input type="text" id="last_name" name="last_name" placeholder="Doe" required />
                </div>
              </div>
              <div className="form-group">
                <label htmlFor="email">Work Email</label>
                <input type="email" id="email" name="email" placeholder="john@company.com" required />
              </div>
              <div className="form-group">
                <label htmlFor="company">Company</label>
                <input type="text" id="company" name="company" placeholder="Acme Inc." required />
              </div>
              <button type="submit" className="btn btn-primary btn-block">Get Started</button>
            </form>
            <iframe name="w2l_iframe" id="w2l_iframe" style={{ display: 'none' }} title="hidden-iframe"></iframe>
          </>
        ) : (
          <div className="modal-success" style={{ display: 'block' }}>
            <div className="success-icon">✓</div>
            <h3>You&apos;re All Set!</h3>
            <p>We&apos;ve received your request. Our team will reach out within 24 hours.</p>
            <button className="btn btn-outline btn-block" style={{ marginTop: '24px' }} onClick={handleClose}>
              Close Window
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
