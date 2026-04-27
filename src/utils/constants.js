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

  // Salesforce API endpoints
  SALESFORCE_AUTH_URL: `${process.env.SALESFORCE_INSTANCE_URL}/services/oauth2/authorize`,
  SALESFORCE_TOKEN_URL: `${process.env.SALESFORCE_INSTANCE_URL}/services/oauth2/token`,
  SALESFORCE_REST_API_BASE: `${process.env.SALESFORCE_INSTANCE_URL}/services/data`,
  SALESFORCE_SOAP_API_BASE: `${process.env.SALESFORCE_INSTANCE_URL}/services/Soap/c`,

  // Salesforce API versions
  SALESFORCE_API_VERSION: 'v58.0',

  // Default timeouts
  API_TIMEOUT: parseInt(process.env.API_TIMEOUT) || 30000,
  RETRY_ATTEMPTS: parseInt(process.env.RETRY_ATTEMPTS) || 3,
  RETRY_DELAY: parseInt(process.env.RETRY_DELAY) || 1000,

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
