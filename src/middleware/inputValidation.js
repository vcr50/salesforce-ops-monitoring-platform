const { ORG_ID_PATTERN } = require('./requestContext');

const BLOCKED_KEYS = new Set(['__proto__', 'constructor', 'prototype']);
const SALESFORCE_ID_PATTERN = /^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/;
const SAFE_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const validationError = (req, res, code, message, details = {}) => res.status(400).json({
  error: {
    code,
    message,
    status: 400,
    requestId: req.context?.requestId,
    ...details
  }
});

const hasBlockedKey = (value) => {
  if (!value || typeof value !== 'object') {
    return false;
  }

  if (Array.isArray(value)) {
    return value.some(hasBlockedKey);
  }

  return Object.keys(value).some((key) => BLOCKED_KEYS.has(key) || hasBlockedKey(value[key]));
};

const findContextConflicts = (value, context, path = 'body') => {
  if (!value || typeof value !== 'object') {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((item, index) => findContextConflicts(item, context, `${path}[${index}]`));
  }

  return Object.entries(value).flatMap(([key, child]) => {
    const lowerKey = key.toLowerCase();
    const currentPath = `${path}.${key}`;
    const conflicts = [];

    if (['orgid', 'salesforceorgid', 'sf_org_id'].includes(lowerKey) && child !== context.orgId) {
      conflicts.push({ field: currentPath, expected: context.orgId });
    }

    if (['tenantid', 'tenant_id'].includes(lowerKey) && child !== context.tenantId) {
      conflicts.push({ field: currentPath, expected: context.tenantId });
    }

    return conflicts.concat(findContextConflicts(child, context, currentPath));
  });
};

const validateParams = (req, res) => {
  const { objectName, recordId, sessionId } = req.params;

  if (objectName && !SAFE_NAME_PATTERN.test(objectName)) {
    return validationError(req, res, 'INVALID_OBJECT_NAME', 'Object names must be alphanumeric Salesforce API names.');
  }

  if (recordId && !SALESFORCE_ID_PATTERN.test(recordId)) {
    return validationError(req, res, 'INVALID_RECORD_ID', 'Record ids must be 15 or 18 character Salesforce ids.');
  }

  if (sessionId && !/^[a-zA-Z0-9:_-]{1,100}$/.test(sessionId)) {
    return validationError(req, res, 'INVALID_SESSION_ID', 'Session ids may only contain letters, numbers, colon, underscore, or dash.');
  }

  return null;
};

const validateQuery = (req, res) => {
  const { limit, startDate, endDate, orgId, tenantId } = req.query;

  if (limit !== undefined) {
    const parsedLimit = Number(limit);
    if (!Number.isInteger(parsedLimit) || parsedLimit < 1 || parsedLimit > 500) {
      return validationError(req, res, 'INVALID_LIMIT', 'Query limit must be an integer between 1 and 500.');
    }
  }

  if (startDate && !ISO_DATE_PATTERN.test(startDate)) {
    return validationError(req, res, 'INVALID_START_DATE', 'startDate must use YYYY-MM-DD format.');
  }

  if (endDate && !ISO_DATE_PATTERN.test(endDate)) {
    return validationError(req, res, 'INVALID_END_DATE', 'endDate must use YYYY-MM-DD format.');
  }

  if (orgId && (!ORG_ID_PATTERN.test(orgId) || orgId !== req.context.orgId)) {
    return validationError(req, res, 'ORG_CONTEXT_MISMATCH', 'Request org id must match x-sf-org-id.');
  }

  if (tenantId && tenantId !== req.context.tenantId) {
    return validationError(req, res, 'TENANT_CONTEXT_MISMATCH', 'Request tenant id must match x-tenant-id.');
  }

  return null;
};

const inputValidation = (req, res, next) => {
  if (!req.path.startsWith('/api') || !req.context) {
    return next();
  }

  if (hasBlockedKey(req.body) || hasBlockedKey(req.query) || hasBlockedKey(req.params)) {
    return validationError(req, res, 'UNSAFE_REQUEST_SHAPE', 'Request contains a reserved object key.');
  }

  const paramError = validateParams(req, res);
  if (paramError) return paramError;

  const queryError = validateQuery(req, res);
  if (queryError) return queryError;

  const conflicts = findContextConflicts(req.body, req.context);
  if (conflicts.length > 0) {
    return validationError(req, res, 'TENANT_CONTEXT_MISMATCH', 'Request payload tenant context must match authenticated tenant context.', {
      conflicts
    });
  }

  return next();
};

module.exports = {
  inputValidation,
  hasBlockedKey,
  findContextConflicts
};
