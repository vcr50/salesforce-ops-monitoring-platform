const {
  sentinelFlowConfig,
  getFoundationStatus
} = require('../config/sentinelFlow');

const getSystemContext = (req, res) => {
  res.json({
    platform: sentinelFlowConfig.platform,
    environment: sentinelFlowConfig.environment,
    services: sentinelFlowConfig.services,
    salesforce: {
      customObjects: Object.keys(sentinelFlowConfig.salesforce.customObjects)
    },
    timestamp: new Date().toISOString()
  });
};

const getReadiness = (req, res) => {
  res.json({
    status: 'ok',
    readiness: getFoundationStatus(),
    timestamp: new Date().toISOString()
  });
};

module.exports = {
  getSystemContext,
  getReadiness
};
