const express = require('express');
const recordsController = require('../controllers/recordsController');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Apply authentication to all record routes
router.use(authMiddleware);

router.get('/:objectName', recordsController.getRecords);
router.post('/:objectName', recordsController.createRecord);
router.get('/:objectName/:recordId', recordsController.getRecord);
router.patch('/:objectName/:recordId', recordsController.updateRecord);
router.delete('/:objectName/:recordId', recordsController.deleteRecord);
router.get('/query/soql', recordsController.queryRecords);

module.exports = router;
