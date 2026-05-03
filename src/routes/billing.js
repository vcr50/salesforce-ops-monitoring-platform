const express = require('express');
const billingController = require('../controllers/billingController');

const router = express.Router();

router.post('/create-checkout-session', billingController.createCheckoutSession);
router.post('/portal', billingController.createPortalSession);

module.exports = router;
