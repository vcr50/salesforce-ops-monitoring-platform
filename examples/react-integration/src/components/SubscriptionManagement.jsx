/**
 * SubscriptionManagement Component
 * Manages existing subscriptions with plan changes and cancellation
 */

import React, { useState, useEffect } from 'react';
import { billingService } from '../services/billing';
import './SubscriptionManagement.css';

const SubscriptionManagement = ({ customerId, orgId }) => {
  const [subscription, setSubscription] = useState(null);
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [showChangePlanDialog, setShowChangePlanDialog] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    loadData();
  }, [customerId]);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);

      const [subscriptionData, plansData] = await Promise.all([
        billingService.getCustomerSubscription(customerId),
        billingService.getPlans()
      ]);

      setSubscription(subscriptionData.data.subscription);
      setPlans(plansData.data.plans);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = async (immediate = false) => {
    if (!confirm('Are you sure you want to cancel your subscription?')) {
      return;
    }

    try {
      setProcessing(true);
      await billingService.cancelSubscription(subscription.id, immediate);
      setShowCancelDialog(false);
      await loadData();
      alert('Subscription cancelled successfully');
    } catch (err) {
      setError(err.message);
      setProcessing(false);
    }
  };

  const handleChangePlan = async () => {
    if (!selectedPlan) {
      alert('Please select a plan');
      return;
    }

    try {
      setProcessing(true);
      await billingService.changePlan(subscription.id, selectedPlan.id);
      setShowChangePlanDialog(false);
      await loadData();
      alert('Plan changed successfully');
    } catch (err) {
      setError(err.message);
      setProcessing(false);
    }
  };

  const openPortal = async () => {
    try {
      setProcessing(true);
      const { url } = await billingService.createPortalSession({ orgId });
      window.location.href = url;
    } catch (err) {
      setError(err.message);
      setProcessing(false);
    }
  };

  if (loading) {
    return <div className="subscription-management loading">Loading subscription...</div>;
  }

  if (error) {
    return (
      <div className="subscription-management error">
        <p>Error: {error}</p>
        <button onClick={loadData}>Retry</button>
      </div>
    );
  }

  if (!subscription) {
    return (
      <div className="subscription-management no-subscription">
        <p>No active subscription found</p>
      </div>
    );
  }

  const currentPlan = plans.find(p => p.name === subscription.metadata?.plan);
  const nextBillingDate = subscription.current_period_end 
    ? new Date(subscription.current_period_end * 1000).toLocaleDateString()
    : 'N/A';

  return (
    <div className="subscription-management">
      <div className="subscription-management__header">
        <h2>Subscription Management</h2>
        <p>Manage your subscription and billing preferences</p>
      </div>

      <div className="subscription-card">
        <div className="subscription-card__header">
          <div>
            <h3>Current Plan: {currentPlan?.name || subscription.metadata?.plan}</h3>
            <p className="status">Status: <span className={`status--${subscription.status}`}>{subscription.status}</span></p>
          </div>
          <div className="price">
            ${currentPlan?.price || 0}/{currentPlan?.interval || 'month'}
          </div>
        </div>

        <div className="subscription-card__details">
          <div className="detail-item">
            <span className="detail-label">Next Billing Date:</span>
            <span className="detail-value">{nextBillingDate}</span>
          </div>
          <div className="detail-item">
            <span className="detail-label">Subscription ID:</span>
            <span className="detail-value">{subscription.id}</span>
          </div>
        </div>

        <div className="subscription-card__actions">
          <button
            className="btn btn--primary"
            onClick={() => setShowChangePlanDialog(true)}
            disabled={processing}
          >
            Change Plan
          </button>
          <button
            className="btn btn--secondary"
            onClick={openPortal}
            disabled={processing}
          >
            Manage Payment Methods
          </button>
          <button
            className="btn btn--danger"
            onClick={() => setShowCancelDialog(true)}
            disabled={processing}
          >
            Cancel Subscription
          </button>
        </div>
      </div>

      {showCancelDialog && (
        <div className="dialog">
          <div className="dialog__content">
            <h3>Cancel Subscription</h3>
            <p>Are you sure you want to cancel your subscription?</p>
            <div className="dialog__actions">
              <button
                className="btn btn--secondary"
                onClick={() => setShowCancelDialog(false)}
                disabled={processing}
              >
                Keep Subscription
              </button>
              <button
                className="btn btn--danger"
                onClick={() => handleCancel(false)}
                disabled={processing}
              >
                Cancel at Period End
              </button>
              <button
                className="btn btn--danger"
                onClick={() => handleCancel(true)}
                disabled={processing}
              >
                Cancel Immediately
              </button>
            </div>
          </div>
        </div>
      )}

      {showChangePlanDialog && (
        <div className="dialog">
          <div className="dialog__content dialog__content--large">
            <h3>Change Your Plan</h3>
            <div className="plan-selection">
              {plans.map(plan => (
                <div
                  key={plan.id}
                  className={`plan-option ${selectedPlan?.id === plan.id ? 'plan-option--selected' : ''}`}
                  onClick={() => setSelectedPlan(plan)}
                >
                  <div className="plan-option__header">
                    <h4>{plan.name}</h4>
                    <span className="price">${plan.price}/{plan.interval}</span>
                  </div>
                  <ul className="plan-option__features">
                    {plan.features.map((feature, index) => (
                      <li key={index}>{feature}</li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
            <div className="dialog__actions">
              <button
                className="btn btn--secondary"
                onClick={() => {
                  setShowChangePlanDialog(false);
                  setSelectedPlan(null);
                }}
                disabled={processing}
              >
                Cancel
              </button>
              <button
                className="btn btn--primary"
                onClick={handleChangePlan}
                disabled={processing || !selectedPlan}
              >
                {processing ? 'Processing...' : 'Change Plan'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionManagement;
