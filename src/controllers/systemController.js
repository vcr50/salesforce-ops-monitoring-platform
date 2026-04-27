const {
  seompConfig,
  getFoundationStatus
} = require('../config/seomp');

const getSystemContext = (req, res) => {
  res.json({
    platform: seompConfig.platform,
    environment: seompConfig.environment,
    services: seompConfig.services,
    salesforce: {
      customObjects: Object.keys(seompConfig.salesforce.customObjects)
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
