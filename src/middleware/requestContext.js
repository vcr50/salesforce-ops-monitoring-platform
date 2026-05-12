const crypto = require('crypto');

const ORG_ID_PATTERN = /^00D[a-zA-Z0-9]{12,15}$/;

const publicApiPaths = new Set([
  '/api/billing/webhook'
]);

const getHeader = (req, name) => req.get(name) || req.get(name.toLowerCase());

const normalizeRequestId = (value) => {
  if (value && String(value).trim()) {
    return String(value).trim();
  }
  return crypto.randomUUID();
};

const tenantContext = (req, res, next) => {
  if (!req.path.startsWith('/api') || publicApiPaths.has(req.path)) {
    return next();
  }

  const orgId = getHeader(req, 'x-sf-org-id') || getHeader(req, 'x-salesforce-org-id');
  const tenantId = getHeader(req, 'x-tenant-id') || orgId;
  const userId = getHeader(req, 'x-sf-user-id') || getHeader(req, 'x-salesforce-user-id') || 'system';
  const packageVersion = getHeader(req, 'x-package-version') || process.env.SEOMP_VERSION || 'unknown';
  const requestId = normalizeRequestId(getHeader(req, 'x-request-id'));

  res.setHeader('x-request-id', requestId);

  if (!orgId || !ORG_ID_PATTERN.test(orgId)) {
    return res.status(400).json({
      error: {
        code: 'TENANT_CONTEXT_REQUIRED',
        message: 'A valid Salesforce org id is required in x-sf-org-id.',
        status: 400,
        requestId
      }
    });
  }

  req.context = {
    tenantId,
    orgId,
    userId,
    packageVersion,
    requestId
  };

  return next();
};

module.exports = {
  tenantContext,
  ORG_ID_PATTERN
};
