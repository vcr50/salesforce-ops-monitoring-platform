/**
 * Subscription Routes
 * Defines all subscription-related API endpoints
 */

const express = require('express');
const router = express.Router();
const subscriptionController = require('../controllers/subscriptionController');

// Plan Management
router.get('/plans', subscriptionController.getPlans);
router.get('/plans/:planId', subscriptionController.getPlanById);

// Subscription CRUD
router.post('/', subscriptionController.createSubscription);
router.get('/:subscriptionId', subscriptionController.getSubscription);
router.patch('/:subscriptionId', subscriptionController.updateSubscription);
router.post('/:subscriptionId/cancel', subscriptionController.cancelSubscription);

// Plan Changes
router.post('/:subscriptionId/change-plan', subscriptionController.changePlan);

// Usage and Stats
router.get('/:subscriptionId/usage', subscriptionController.getUsageStats);

// Customer Portal
router.post('/portal', subscriptionController.createPortalSession);

// Customer Operations
router.get('/customer/:customerId', subscriptionController.getCustomerSubscription);
router.get('/customer/:customerId/payment-methods', subscriptionController.getCustomerPaymentMethods);
router.get('/customer/:customerId/invoices', subscriptionController.getCustomerInvoices);
router.get('/customer/:customerId/upcoming-invoice', subscriptionController.getUpcomingInvoice);

module.exports = router;
