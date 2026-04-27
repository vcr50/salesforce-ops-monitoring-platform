const express = require('express');
const systemController = require('../controllers/systemController');

const router = express.Router();

router.get('/context', systemController.getSystemContext);
router.get('/readiness', systemController.getReadiness);

module.exports = router;
