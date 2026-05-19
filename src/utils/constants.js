const getSalesforceBaseUrl = () => {
  const url = process.env.SALESFORCE_INSTANCE_URL;
  if (!url) return '';
  return url.replace(/\/$/, '');
};

module.exports = {
  // HTTP Status Codes
  HTTP_OK: 200,
  HTTP_CREATED: 201,
  HTTP_BAD_REQUEST: 400,
  HTTP_UNAUTHORIZED: 401,
  HTTP_FORBIDDEN: 403,
  HTTP_NOT_FOUND: 404,
  HTTP_CONFLICT: 409,
  HTTP_SERVER_ERROR: 500,

  // Salesforce API endpoints — lazy getters so env vars are read at access time
  get SALESFORCE_AUTH_URL() {
    return `${getSalesforceBaseUrl()}/services/oauth2/authorize`;
  },
  get SALESFORCE_TOKEN_URL() {
    return `${getSalesforceBaseUrl()}/services/oauth2/token`;
  },
  get SALESFORCE_REST_API_BASE() {
    return `${getSalesforceBaseUrl()}/services/data`;
  },
  get SALESFORCE_SOAP_API_BASE() {
    return `${getSalesforceBaseUrl()}/services/Soap/c`;
  },

  // Salesforce API versions
  SALESFORCE_API_VERSION: 'v58.0',

  // Default timeouts — lazy getters so env vars are read at access time
  get API_TIMEOUT() {
    return parseInt(process.env.API_TIMEOUT) || 30000;
  },
  get RETRY_ATTEMPTS() {
    return parseInt(process.env.RETRY_ATTEMPTS) || 3;
  },
  get RETRY_DELAY() {
    return parseInt(process.env.RETRY_DELAY) || 1000;
  },

  // Sync configuration
  SYNC_BATCH_SIZE: 100,
  SYNC_TIMEOUT: 5 * 60 * 1000, // 5 minutes

  // Common Salesforce objects
  STANDARD_OBJECTS: [
    'Account',
    'Contact',
    'Lead',
    'Opportunity',
    'Case',
    'Task',
    'Event'
  ]
};
