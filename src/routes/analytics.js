const express = require('express');
const analyticsController = require('../controllers/analyticsController');

const router = express.Router();

router.get('/dashboard', analyticsController.getDashboard);
router.get('/records/:objectName', analyticsController.getObjectAnalytics);
router.post('/report', analyticsController.generateReport);
router.post('/event', analyticsController.recordEvent);

module.exports = router;
