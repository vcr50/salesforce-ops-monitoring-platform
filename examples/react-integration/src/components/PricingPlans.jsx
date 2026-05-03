/**
 * PricingPlans Component
 * Displays available subscription plans with checkout functionality
 */

import React, { useState, useEffect } from 'react';
import { billingService } from '../services/billing';
import './PricingPlans.css';

const PricingPlans = ({ orgId, email, name }) => {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [processingPlan, setProcessingPlan] = useState(null);

  useEffect(() => {
    loadPlans();
  }, []);

  const loadPlans = async () => {
    try {
      setLoading(true);
      setError(null);
      const { data } = await billingService.getPlans();
      setPlans(data.plans);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectPlan = async (planName) => {
    if (!orgId || !email) {
      alert('Organization ID and email are required');
      return;
    }

    try {
      setProcessingPlan(planName);
      const { url } = await billingService.createCheckoutSession({
        orgId,
        email,
        name,
        plan: planName
      });
      window.location.href = url;
    } catch (err) {
      setError(err.message);
      setProcessingPlan(null);
    }
  };

  if (loading) {
    return <div className="pricing-plans loading">Loading plans...</div>;
  }

  if (error) {
    return (
      <div className="pricing-plans error">
        <p>Error loading plans: {error}</p>
        <button onClick={loadPlans}>Retry</button>
      </div>
    );
  }

  return (
    <div className="pricing-plans">
      <div className="pricing-plans__header">
        <h2>Choose Your Plan</h2>
        <p>Select the plan that best fits your needs</p>
      </div>

      <div className="pricing-plans__grid">
        {plans.map((plan) => (
          <div
            key={plan.id}
            className={`pricing-card ${plan.name === 'Professional' ? 'pricing-card--highlight' : ''}`}
          >
            {plan.name === 'Professional' && (
              <div className="badge">Most Popular</div>
            )}

            <h3 className="plan-name">{plan.name}</h3>

            <div className="plan-price-wrap">
              <span className="plan-price">${plan.price}</span>
              <span className="plan-price-period">/{plan.interval}</span>
            </div>

            <p className="plan-desc">
              {plan.name === 'Starter' && 'Perfect for getting started'}
              {plan.name === 'Professional' && 'Best for growing teams'}
              {plan.name === 'Enterprise' && 'For large organizations'}
            </p>

            <div className="plan-divider"></div>

            <div className="feature-label">Features</div>
            <ul className="feature-list">
              {plan.features.map((feature, index) => (
                <li key={index} className="feature-item">
                  <span className={`feature-icon ${plan.name === 'Professional' ? 'check-blue' : 'check-default'}`}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <circle className="check-circle" cx="12" cy="12" r="10"></circle>
                      <path className="check-mark" d="M8 12l3 3 5-5"></path>
                    </svg>
                  </span>
                  <span>{feature}</span>
                </li>
              ))}
            </ul>

            <button
              className={`btn ${plan.name === 'Professional' ? 'btn--primary' : 'btn--secondary'}`}
              onClick={() => handleSelectPlan(plan.name)}
              disabled={processingPlan === plan.name}
            >
              {processingPlan === plan.name ? 'Processing...' : `Choose ${plan.name}`}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default PricingPlans;
