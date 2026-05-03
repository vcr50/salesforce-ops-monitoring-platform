/**
 * Customer Routes
 * Defines all customer-related API endpoints
 */

const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');

// Customer CRUD
router.post('/', customerController.createCustomer);
router.get('/:customerId', customerController.getCustomer);
router.patch('/:customerId', customerController.updateCustomer);
router.delete('/:customerId', customerController.deleteCustomer);

// Find customer by organization
router.get('/org/:orgId', customerController.findCustomerByOrgId);

// Get or create customer
router.post('/get-or-create', customerController.getOrCreateCustomer);

module.exports = router;
