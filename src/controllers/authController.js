const { logger } = require('../middleware/logger');
const { config } = require('../config');

const login = (req, res) => {
  // Redirect to Salesforce OAuth login
  const clientId = config.oauth.clientId;
  const redirectUri = encodeURIComponent(config.oauth.callbackUrl || '');
  const scope = encodeURIComponent('api refresh_token');
  const responseType = 'code';
  const instanceUrl = config.salesforce.instanceUrl || '';

  const loginUrl = `${instanceUrl}/services/oauth2/authorize?` +
    `client_id=${clientId}&` +
    `redirect_uri=${redirectUri}&` +
    `response_type=${responseType}&` +
    `scope=${scope}`;

  res.redirect(loginUrl);
};

const callback = (req, res, next) => {
  try {
    const { code, error } = req.query;

    if (error) {
      logger.error(`OAuth error: ${error}`);
      return res.status(400).json({
        error: 'OAuth authorization failed',
        details: error
      });
    }

    if (!code) {
      return res.status(400).json({
        error: 'No authorization code received'
      });
    }

    // In a real implementation, exchange code for token here
    // For now, just log it
    logger.info(`OAuth callback received with code: ${code.substring(0, 20)}...`);

    // Store user info in session
    req.session.user = {
      code,
      accessToken: null, // Would be set after token exchange
      instanceUrl: config.salesforce.instanceUrl
    };

    res.json({
      message: 'Authentication successful',
      code: code.substring(0, 20) + '...'
    });
  } catch (error) {
    next(error);
  }
};

const logout = (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' });
    }
    res.json({ message: 'Logged out successfully' });
  });
};

const getUser = (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({
      error: 'Not authenticated'
    });
  }

  res.json({
    user: req.user
  });
};

module.exports = {
  login,
  callback,
  logout,
  getUser
};
