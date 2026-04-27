class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
    this.status = 400;
  }
}

class AuthenticationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'AuthenticationError';
    this.status = 401;
  }
}

class SalesforceError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.name = 'SalesforceError';
    this.status = statusCode;
  }
}

module.exports = {
  ValidationError,
  AuthenticationError,
  SalesforceError
};
