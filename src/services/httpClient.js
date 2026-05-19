
/**
 * HTTP Client Wrapper
 * Centralizes axios instance creation so services can receive
 * an injectable client instead of calling axios directly.
 * In tests, pass a stubbed client — no jest.mock('axios') needed.
 */

const axios = require('axios');
const { logger } = require('../middleware/logger');

/**
 * Create an HTTP client with default configuration.
 * @param {Object} options
 * @param {string} options.baseURL - Base URL for all requests
 * @param {number} options.timeout - Request timeout in ms (default 15000)
 * @param {Object} options.headers - Default headers
 * @param {Object} options.auth - { username, password } for basic auth
 * @returns {Object} Axios instance with .get, .post, .put, .patch, .delete
 */
const createHttpClient = ({ baseURL, timeout = 15000, headers = {}, auth = null } = {}) => {
  const config = {
    baseURL,
    timeout,
    headers: {
      'Content-Type': 'application/json',
      ...headers
    }
  };

  if (auth) {
    config.auth = auth;
  }

  const instance = axios.create(config);

  // Request interceptor for logging
  instance.interceptors.request.use(
    (requestConfig) => {
      logger.debug({
        method: requestConfig.method,
        url: requestConfig.url
      }, 'HTTP request');
      return requestConfig;
    },
    (error) => Promise.reject(error)
  );

  // Response interceptor for logging
  instance.interceptors.response.use(
    (response) => response,
    (error) => {
      logger.error({
        method: error.config?.method,
        url: error.config?.url,
        status: error.response?.status
      }, 'HTTP request failed');
      return Promise.reject(error);
    }
  );

  return instance;
};

module.exports = { createHttpClient };
