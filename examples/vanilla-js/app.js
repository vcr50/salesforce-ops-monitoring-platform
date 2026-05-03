/**
 * Main Application
 * Handles UI interactions and billing operations
 */

// Configuration - Update these with your actual values
const CONFIG = {
  orgId: 'your-org-id',
  email: 'user@example.com',
  name: 'John Doe',
  customerId: 'cus_your-customer-id'
};

// State
let currentPlan = null;
let selectedPlanForChange = null;

// DOM Elements
const plansContainer = document.getElementById('plans-container');
const subscriptionContainer = document.getElementById('subscription-container');
const planDialog = document.getElementById('plan-dialog');
const cancelDialog = document.getElementById('cancel-dialog');
const planOptions = document.getElementById('plan-options');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  initializeTabs();
  loadPlans();
  loadSubscription();
  initializeDialogs();
});

// Tab Navigation
function initializeTabs() {
  const tabs = document.querySelectorAll('.tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      // Remove active class from all tabs and contents
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

      // Add active class to clicked tab and corresponding content
      tab.classList.add('active');
      document.getElementById(`${tab.dataset.tab}-tab`).classList.add('active');
    });
  });
}

// Load Plans
async function loadPlans() {
  try {
    const { data } = await window.billingAPI.getPlans();
    renderPlans(data.plans);
  } catch (error) {
    plansContainer.innerHTML = `
      <div class="error">
        <p>Error loading plans: ${error.message}</p>
        <button onclick="loadPlans()" class="btn btn-primary">Retry</button>
      </div>
    `;
  }
}

// Render Plans
function renderPlans(plans) {
  plansContainer.innerHTML = plans.map(plan => `
    <div class="plan-card ${plan.name === 'Professional' ? 'highlight' : ''}">
      ${plan.name === 'Professional' ? '<div class="badge">Most Popular</div>' : ''}
      <h3 class="plan-name">${plan.name}</h3>
      <div class="plan-price-wrap">
        <span class="plan-price">$${plan.price}</span>
        <span class="plan-price-period">/${plan.interval}</span>
      </div>
      <p class="plan-desc">
        ${plan.name === 'Starter' ? 'Perfect for getting started' : ''}
        ${plan.name === 'Professional' ? 'Best for growing teams' : ''}
        ${plan.name === 'Enterprise' ? 'For large organizations' : ''}
      </p>
      <div class="plan-divider"></div>
      <div class="feature-label">Features</div>
      <ul class="feature-list">
        ${plan.features.map(feature => `
          <li class="feature-item">
            <span class="feature-icon ${plan.name === 'Professional' ? 'check-blue' : 'check-default'}">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle class="check-circle" cx="12" cy="12" r="10"></circle>
                <path class="check-mark" d="M8 12l3 3 5-5"></path>
              </svg>
            </span>
            <span>${feature}</span>
          </li>
        `).join('')}
      </ul>
      <button 
        class="btn ${plan.name === 'Professional' ? 'btn-primary' : 'btn-secondary'}"
        onclick="selectPlan('${plan.name}')"
      >
        Choose ${plan.name}
      </button>
    </div>
  `).join('');
}

// Select Plan
async function selectPlan(planName) {
  try {
    const { url } = await window.billingAPI.createCheckoutSession({
      orgId: CONFIG.orgId,
      email: CONFIG.email,
      name: CONFIG.name,
      plan: planName
    });
    window.location.href = url;
  } catch (error) {
    alert(`Failed to start checkout: ${error.message}`);
  }
}

// Load Subscription
async function loadSubscription() {
  try {
    const { data } = await window.billingAPI.getCustomerSubscription(CONFIG.customerId);
    currentPlan = data.subscription;
    renderSubscription(data.subscription);
  } catch (error) {
    subscriptionContainer.innerHTML = `
      <div class="no-subscription">
        <p>No active subscription found</p>
      </div>
    `;
  }
}

// Render Subscription
function renderSubscription(subscription) {
  const nextBillingDate = subscription.current_period_end 
    ? new Date(subscription.current_period_end * 1000).toLocaleDateString()
    : 'N/A';

  subscriptionContainer.innerHTML = `
    <div class="subscription-card">
      <div class="subscription-card__header">
        <div>
          <h3>Current Plan: ${subscription.metadata?.plan || 'Unknown'}</h3>
          <p class="status status--${subscription.status}">Status: ${subscription.status}</p>
        </div>
        <div class="price">$49/month</div>
      </div>
      <div class="subscription-card__details">
        <div class="detail-item">
          <span class="detail-label">Next Billing Date:</span>
          <span class="detail-value">${nextBillingDate}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">Subscription ID:</span>
          <span class="detail-value">${subscription.id}</span>
        </div>
      </div>
      <div class="subscription-card__actions">
        <button class="btn btn-primary" onclick="openPlanDialog()">Change Plan</button>
        <button class="btn btn-secondary" onclick="openPortal()">Manage Payment Methods</button>
        <button class="btn btn-danger" onclick="openCancelDialog()">Cancel Subscription</button>
      </div>
    </div>
  `;
}

// Initialize Dialogs
function initializeDialogs() {
  // Plan change dialog
  document.getElementById('cancel-plan-change').addEventListener('click', () => {
    closeDialog(planDialog);
    selectedPlanForChange = null;
  });

  document.getElementById('confirm-plan-change').addEventListener('click', handlePlanChange);

  // Cancel dialog
  document.getElementById('keep-subscription').addEventListener('click', () => {
    closeDialog(cancelDialog);
  });

  document.getElementById('cancel-at-end').addEventListener('click', () => handleCancel(false));
  document.getElementById('cancel-immediate').addEventListener('click', () => handleCancel(true));

  // Close dialogs on outside click
  [planDialog, cancelDialog].forEach(dialog => {
    dialog.addEventListener('click', (e) => {
      if (e.target === dialog) {
        closeDialog(dialog);
        selectedPlanForChange = null;
      }
    });
  });
}

// Open Plan Dialog
async function openPlanDialog() {
  try {
    const { data } = await window.billingAPI.getPlans();
    renderPlanOptions(data.plans);
    openDialog(planDialog);
  } catch (error) {
    alert(`Failed to load plans: ${error.message}`);
  }
}

// Render Plan Options
function renderPlanOptions(plans) {
  planOptions.innerHTML = plans.map(plan => `
    <div 
      class="plan-option ${selectedPlanForChange?.id === plan.id ? 'selected' : ''}"
      onclick="selectPlanForChange('${plan.id}')"
    >
      <div class="plan-option__header">
        <h4>${plan.name}</h4>
        <span class="price">$${plan.price}/${plan.interval}</span>
      </div>
      <ul class="plan-option__features">
        ${plan.features.map(feature => `<li>${feature}</li>`).join('')}
      </ul>
    </div>
  `).join('');
}

// Select Plan for Change
function selectPlanForChange(planId) {
  const { data } = window.billingAPI.getPlans().then(r => r);
  selectedPlanForChange = data.plans.find(p => p.id === planId);

  // Update UI
  document.querySelectorAll('.plan-option').forEach(option => {
    option.classList.remove('selected');
  });
  event.currentTarget.classList.add('selected');

  // Enable confirm button
  document.getElementById('confirm-plan-change').disabled = false;
}

// Handle Plan Change
async function handlePlanChange() {
  if (!selectedPlanForChange) {
    alert('Please select a plan');
    return;
  }

  try {
    await window.billingAPI.changePlan(currentPlan.id, selectedPlanForChange.id);
    closeDialog(planDialog);
    selectedPlanForChange = null;
    await loadSubscription();
    alert('Plan changed successfully');
  } catch (error) {
    alert(`Failed to change plan: ${error.message}`);
  }
}

// Open Cancel Dialog
function openCancelDialog() {
  openDialog(cancelDialog);
}

// Handle Cancel
async function handleCancel(immediate) {
  try {
    await window.billingAPI.cancelSubscription(currentPlan.id, immediate);
    closeDialog(cancelDialog);
    await loadSubscription();
    alert('Subscription cancelled successfully');
  } catch (error) {
    alert(`Failed to cancel subscription: ${error.message}`);
  }
}

// Open Portal
async function openPortal() {
  try {
    const { url } = await window.billingAPI.createPortalSession({ orgId: CONFIG.orgId });
    window.location.href = url;
  } catch (error) {
    alert(`Failed to open portal: ${error.message}`);
  }
}

// Dialog Helpers
function openDialog(dialog) {
  dialog.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function closeDialog(dialog) {
  dialog.classList.add('hidden');
  document.body.style.overflow = '';
}

// Make functions globally available
window.selectPlan = selectPlan;
window.openPlanDialog = openPlanDialog;
window.selectPlanForChange = selectPlanForChange;
window.openCancelDialog = openCancelDialog;
window.openPortal = openPortal;
