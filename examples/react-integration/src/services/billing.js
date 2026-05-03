/**
 * Billing Service
 * Handles all billing-related API calls
 */

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'https://your-api.com/api';

class BillingService {
  async request(endpoint, options = {}) {
    const token = localStorage.getItem('authToken');

    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers
      },
      ...options
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Request failed');
    }

    return response.json();
  }

  // Checkout
  async createCheckoutSession(data) {
    return this.request('/billing/create-checkout-session', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async createPortalSession(data) {
    return this.request('/billing/portal', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  // Plans
  async getPlans() {
    return this.request('/subscriptions/plans');
  }

  async getPlanById(planId) {
    return this.request(`/subscriptions/plans/${planId}`);
  }

  // Subscriptions
  async createSubscription(data) {
    return this.request('/subscriptions', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async getSubscription(subscriptionId) {
    return this.request(`/subscriptions/${subscriptionId}`);
  }

  async getCustomerSubscription(customerId) {
    return this.request(`/subscriptions/customer/${customerId}`);
  }

  async updateSubscription(subscriptionId, data) {
    return this.request(`/subscriptions/${subscriptionId}`, {
      method: 'PATCH',
      body: JSON.stringify(data)
    });
  }

  async cancelSubscription(subscriptionId, immediate = false) {
    return this.request(`/subscriptions/${subscriptionId}/cancel`, {
      method: 'POST',
      body: JSON.stringify({ immediate })
    });
  }

  async changePlan(subscriptionId, newPlanId) {
    return this.request(`/subscriptions/${subscriptionId}/change-plan`, {
      method: 'POST',
      body: JSON.stringify({ newPlanId })
    });
  }

  async getUsageStats(subscriptionId) {
    return this.request(`/subscriptions/${subscriptionId}/usage`);
  }

  // Payment Methods
  async getPaymentMethods(customerId) {
    return this.request(`/subscriptions/customer/${customerId}/payment-methods`);
  }

  // Invoices
  async getInvoices(customerId, limit = 10) {
    return this.request(`/subscriptions/customer/${customerId}/invoices?limit=${limit}`);
  }

  async getUpcomingInvoice(customerId, subscriptionId) {
    const query = subscriptionId ? `?subscriptionId=${subscriptionId}` : '';
    return this.request(`/subscriptions/customer/${customerId}/upcoming-invoice${query}`);
  }

  // Customers
  async createCustomer(data) {
    return this.request('/customers', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async getCustomer(customerId) {
    return this.request(`/customers/${customerId}`);
  }

  async getCustomerByOrgId(orgId) {
    return this.request(`/customers/org/${orgId}`);
  }

  async updateCustomer(customerId, data) {
    return this.request(`/customers/${customerId}`, {
      method: 'PATCH',
      body: JSON.stringify(data)
    });
  }

  async deleteCustomer(customerId) {
    return this.request(`/customers/${customerId}`, {
      method: 'DELETE'
    });
  }

  async getOrCreateCustomer(data) {
    return this.request('/customers/get-or-create', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }
}

export const billingService = new BillingService();
