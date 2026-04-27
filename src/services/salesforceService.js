const SalesforceRestAPI = require('../modules/restApi');
const SalesforceSoapAPI = require('../modules/soapApi');
const SalesforceBulkAPI = require('../modules/bulkApi');
const { logger } = require('../middleware/logger');

class SalesforceService {
  constructor(accessToken, instanceUrl) {
    this.accessToken = accessToken;
    this.instanceUrl = instanceUrl;
    this.restAPI = new SalesforceRestAPI(accessToken, instanceUrl);
    this.soapAPI = new SalesforceSoapAPI(accessToken, instanceUrl);
    this.bulkAPI = new SalesforceBulkAPI(accessToken, instanceUrl);
  }

  // REST API methods
  async getRecord(objectName, recordId, fields = []) {
    logger.info(`Fetching ${objectName} record: ${recordId}`);
    return this.restAPI.getObject(objectName, recordId, fields);
  }

  async createRecord(objectName, data) {
    logger.info(`Creating ${objectName} record`);
    return this.restAPI.createObject(objectName, data);
  }

  async updateRecord(objectName, recordId, data) {
    logger.info(`Updating ${objectName} record: ${recordId}`);
    return this.restAPI.updateObject(objectName, recordId, data);
  }

  async deleteRecord(objectName, recordId) {
    logger.info(`Deleting ${objectName} record: ${recordId}`);
    return this.restAPI.deleteObject(objectName, recordId);
  }

  async queryRecords(soqlQuery) {
    logger.info(`Executing SOQL query`);
    return this.restAPI.query(soqlQuery);
  }

  async getAllRecords(objectName, pageSize = 100) {
    logger.info(`Fetching all ${objectName} records`);
    return this.restAPI.getAllRecords(objectName, pageSize);
  }

  // SOAP API methods
  async retrieveRecords(objectType, ids, fields) {
    logger.info(`Retrieving ${ids.length} ${objectType} records via SOAP`);
    return this.soapAPI.retrieve(objectType, ids, fields);
  }

  async querySoap(soqlQuery) {
    logger.info(`Executing SOAP query`);
    return this.soapAPI.query(soqlQuery);
  }

  // Bulk API methods
  async bulkInsert(objectName, csvData) {
    logger.info(`Starting bulk insert for ${objectName}`);
    return this.bulkAPI.performBulkOperation(objectName, csvData, 'insert');
  }

  async bulkUpdate(objectName, csvData) {
    logger.info(`Starting bulk update for ${objectName}`);
    return this.bulkAPI.performBulkOperation(objectName, csvData, 'update');
  }

  async bulkDelete(objectName, csvData) {
    logger.info(`Starting bulk delete for ${objectName}`);
    return this.bulkAPI.performBulkOperation(objectName, csvData, 'delete');
  }

  async bulkUpsert(objectName, csvData) {
    logger.info(`Starting bulk upsert for ${objectName}`);
    return this.bulkAPI.performBulkOperation(objectName, csvData, 'upsert');
  }

  // Helper methods
  async getObjectMetadata(objectName) {
    logger.info(`Fetching metadata for ${objectName}`);
    return this.restAPI.request('GET', `/sobjects/${objectName}/describe`);
  }

  async getAvailableObjects() {
    logger.info(`Fetching available Salesforce objects`);
    return this.restAPI.request('GET', '/sobjects');
  }

  async getLimits() {
    logger.info(`Fetching organization limits`);
    return this.restAPI.request('GET', '/limits');
  }
}

module.exports = SalesforceService;
