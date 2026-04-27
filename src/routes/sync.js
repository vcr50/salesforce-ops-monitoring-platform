const express = require('express');
const syncController = require('../controllers/syncController');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply authentication to all sync routes
router.use(authMiddleware);

router.post('/start', syncController.startSync);
router.get('/status/:sessionId', syncController.getSyncStatus);
router.get('/logs', syncController.getSyncLogs);
router.post('/complete/:sessionId', syncController.completeSync);

module.exports = router;
