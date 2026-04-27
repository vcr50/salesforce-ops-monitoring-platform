const axios = require('axios');
const { logger } = require('../middleware/logger');
const { SalesforceError } = require('../utils/errors');
const { API_TIMEOUT, RETRY_ATTEMPTS, RETRY_DELAY } = require('../utils/constants');

class SalesforceRestAPI {
  constructor(accessToken, instanceUrl) {
    this.accessToken = accessToken;
    this.instanceUrl = instanceUrl;
    this.baseURL = `${instanceUrl}/services/data/v58.0`;
  }

  async request(method, endpoint, data = null, retries = RETRY_ATTEMPTS) {
    try {
      const config = {
        method,
        url: `${this.baseURL}${endpoint}`,
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        },
        timeout: API_TIMEOUT
      };

      if (data) {
        config.data = data;
      }

      const response = await axios(config);
      return response.data;
    } catch (error) {
      if (retries > 0 && this.isRetryableError(error)) {
        logger.warn(`Request failed, retrying... (${RETRY_ATTEMPTS - retries + 1}/${RETRY_ATTEMPTS})`);
        await this.sleep(RETRY_DELAY);
        return this.request(method, endpoint, data, retries - 1);
      }

      const errorMessage = error.response?.data?.[0]?.message || error.message;
      logger.error(`REST API Error: ${errorMessage}`);
      throw new SalesforceError(errorMessage, error.response?.status);
    }
  }

  isRetryableError(error) {
    const retryableStatuses = [408, 429, 500, 502, 503, 504];
    return retryableStatuses.includes(error.response?.status);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async getObject(objectName, recordId, fields = []) {
    const query = fields.length > 0 ? `?fields=${fields.join(',')}` : '';
    return this.request('GET', `/sobjects/${objectName}/${recordId}${query}`);
  }

  async createObject(objectName, data) {
    return this.request('POST', `/sobjects/${objectName}`, data);
  }

  async updateObject(objectName, recordId, data) {
    return this.request('PATCH', `/sobjects/${objectName}/${recordId}`, data);
  }

  async deleteObject(objectName, recordId) {
    return this.request('DELETE', `/sobjects/${objectName}/${recordId}`);
  }

  async query(soqlQuery) {
    return this.request('GET', `/query?q=${encodeURIComponent(soqlQuery)}`);
  }

  async getAllRecords(objectName, pageSize = 100) {
    const results = [];
    let nextUrl = `/sobjects/${objectName}?limit=${pageSize}`;

    while (nextUrl) {
      const response = await this.request('GET', nextUrl);
      results.push(...response.records);

      nextUrl = response.nextRecordsUrl || null;
    }

    return results;
  }
}

module.exports = SalesforceRestAPI;
