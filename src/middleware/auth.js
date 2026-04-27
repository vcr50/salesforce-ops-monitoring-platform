const { logger } = require('./logger');

const authMiddleware = (req, res, next) => {
  if (!req.isAuthenticated()) {
    logger.warn(`Unauthorized access attempt to ${req.path}`);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Please authenticate first'
    });
  }
  next();
};

module.exports = authMiddleware;
