const axios = require('axios');
const { logger } = require('../middleware/logger');
const { SalesforceError } = require('../utils/errors');
const { API_TIMEOUT, RETRY_ATTEMPTS, RETRY_DELAY } = require('../utils/constants');

class SalesforceBulkAPI {
  constructor(accessToken, instanceUrl) {
    this.accessToken = accessToken;
    this.instanceUrl = instanceUrl;
    this.baseURL = `${instanceUrl}/services/data/v58.0/jobs/ingest`;
  }

  async request(method, endpoint, data = null, headers = {}, retries = RETRY_ATTEMPTS) {
    try {
      const config = {
        method,
        url: `${this.baseURL}${endpoint}`,
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
          ...headers
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
        logger.warn(`Bulk API request failed, retrying... (${RETRY_ATTEMPTS - retries + 1}/${RETRY_ATTEMPTS})`);
        await this.sleep(RETRY_DELAY);
        return this.request(method, endpoint, data, headers, retries - 1);
      }

      const errorMessage = error.response?.data?.message || error.message;
      logger.error(`Bulk API Error: ${errorMessage}`);
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

  async createJob(objectName, operation = 'insert') {
    const data = {
      object: objectName,
      operation: operation // insert, update, delete, upsert
    };
    return this.request('POST', '', data);
  }

  async uploadJobData(jobId, csvData) {
    const headers = {
      'Content-Type': 'text/csv'
    };
    return this.request('PUT', `/${jobId}/batches`, csvData, headers);
  }

  async closeJob(jobId) {
    const data = {
      state: 'UploadComplete'
    };
    return this.request('PATCH', `/${jobId}`, data);
  }

  async getJobStatus(jobId) {
    return this.request('GET', `/${jobId}`);
  }

  async waitForJobCompletion(jobId, maxWait = 5 * 60 * 1000) {
    const startTime = Date.now();
    const pollInterval = 5000; // 5 seconds

    while (Date.now() - startTime < maxWait) {
      const status = await this.getJobStatus(jobId);

      if (status.state === 'JobComplete' || status.state === 'Failed') {
        return status;
      }

      await this.sleep(pollInterval);
    }

    throw new SalesforceError(`Job ${jobId} did not complete within ${maxWait}ms`);
  }

  async getFailedRecords(jobId) {
    return this.request('GET', `/${jobId}/failedResults`);
  }

  async getSuccessfulRecords(jobId) {
    return this.request('GET', `/${jobId}/successfulResults`);
  }

  // Helper method to perform a complete bulk operation
  async performBulkOperation(objectName, csvData, operation = 'insert') {
    try {
      logger.info(`Starting bulk ${operation} for ${objectName}`);

      // Create job
      const job = await this.createJob(objectName, operation);
      logger.info(`Created job ${job.id}`);

      // Upload data
      await this.uploadJobData(job.id, csvData);
      logger.info(`Uploaded data for job ${job.id}`);

      // Close job to start processing
      await this.closeJob(job.id);
      logger.info(`Closed job ${job.id}`);

      // Wait for completion
      const result = await this.waitForJobCompletion(job.id);
      logger.info(`Job ${job.id} completed with state: ${result.state}`);

      return {
        jobId: job.id,
        status: result.state,
        successfulResults: await this.getSuccessfulRecords(job.id),
        failedResults: result.state === 'Failed' ? await this.getFailedRecords(job.id) : []
      };
    } catch (error) {
      logger.error(`Bulk operation failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = SalesforceBulkAPI;
