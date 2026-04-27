const dataSync = require('../modules/dataSync');
const getSyncStatus = (req, res, next) => {
  try {
    const { sessionId } = req.params;
    const status = dataSync.getSyncStatus(sessionId);

    if (!status) {
      return res.status(404).json({
        error: 'Sync session not found',
        sessionId
      });
    }

    res.json(status);
  } catch (error) {
    next(error);
  }
};

const getSyncLogs = (req, res, next) => {
  try {
    const { objectName, status, limit } = req.query;
    
    const filter = {
      objectName,
      status,
      limit: limit ? parseInt(limit) : 100
    };

    const logs = dataSync.getSyncLogs(filter);
    res.json({
      total: logs.length,
      logs
    });
  } catch (error) {
    next(error);
  }
};

const startSync = (req, res, next) => {
  try {
    const { objectName, direction } = req.body;

    if (!objectName) {
      return res.status(400).json({
        error: 'objectName is required'
      });
    }

    const session = dataSync.startSync(objectName, direction || 'bidirectional');
    
    res.status(201).json({
      message: 'Sync started',
      session
    });
  } catch (error) {
    next(error);
  }
};

const completeSync = (req, res, next) => {
  try {
    const { sessionId } = req.params;
    const { success, error } = req.body;

    const session = dataSync.completeSync(sessionId, success !== false, error);
    
    res.json({
      message: 'Sync completed',
      session
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  startSync,
  getSyncStatus,
  getSyncLogs,
  completeSync
};
