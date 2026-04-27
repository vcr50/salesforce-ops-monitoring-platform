const SalesforceService = require('../services/salesforceService');
const cacheService = require('../services/cacheService');
const analyticsService = require('../services/analyticsService');
const { validateObjectName, validateRecordId } = require('../utils/validators');

const getRecords = async (req, res, next) => {
  try {
    const { objectName } = req.params;

    if (!validateObjectName(objectName)) {
      return res.status(400).json({
        error: 'Invalid object name'
      });
    }

    // Check cache first
    const cacheKey = `records_${objectName}`;
    const cached = cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        source: 'cache',
        data: cached
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    const records = await salesforceService.getAllRecords(objectName);
    
    // Cache the results
    cacheService.set(cacheKey, records);

    analyticsService.recordEvent(`${objectName}_fetched`, {
      count: records.length
    });

    res.json({
      source: 'salesforce',
      object: objectName,
      count: records.length,
      data: records
    });
  } catch (error) {
    next(error);
  }
};

const getRecord = async (req, res, next) => {
  try {
    const { objectName, recordId } = req.params;
    const { fields } = req.query;

    if (!validateObjectName(objectName)) {
      return res.status(400).json({
        error: 'Invalid object name'
      });
    }

    if (!validateRecordId(recordId)) {
      return res.status(400).json({
        error: 'Invalid record ID'
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    const fieldList = fields ? fields.split(',') : [];
    const record = await salesforceService.getRecord(objectName, recordId, fieldList);

    analyticsService.recordEvent(`${objectName}_retrieved`, {
      recordId
    });

    res.json({
      object: objectName,
      record
    });
  } catch (error) {
    next(error);
  }
};

const createRecord = async (req, res, next) => {
  const { objectName } = req.params;
  const recordData = req.body;

  try {
    if (!validateObjectName(objectName)) {
      return res.status(400).json({
        error: 'Invalid object name'
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    const result = await salesforceService.createRecord(objectName, recordData);

    analyticsService.recordEvent(`${objectName}_created`, {
      recordId: result.id
    });

    // Clear cache for this object
    cacheService.delete(`records_${objectName}`);

    res.status(201).json({
      message: 'Record created',
      object: objectName,
      result
    });
  } catch (error) {
    analyticsService.recordEvent(`${objectName}_error`, {
      operation: 'create',
      error: error.message
    });
    next(error);
  }
};

const updateRecord = async (req, res, next) => {
  const { objectName, recordId } = req.params;
  const recordData = req.body;

  try {
    if (!validateObjectName(objectName)) {
      return res.status(400).json({
        error: 'Invalid object name'
      });
    }

    if (!validateRecordId(recordId)) {
      return res.status(400).json({
        error: 'Invalid record ID'
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    await salesforceService.updateRecord(objectName, recordId, recordData);

    analyticsService.recordEvent(`${objectName}_updated`, {
      recordId
    });

    // Clear cache for this object
    cacheService.delete(`records_${objectName}`);

    res.json({
      message: 'Record updated',
      object: objectName,
      recordId
    });
  } catch (error) {
    analyticsService.recordEvent(`${objectName}_error`, {
      operation: 'update',
      error: error.message
    });
    next(error);
  }
};

const deleteRecord = async (req, res, next) => {
  const { objectName, recordId } = req.params;

  try {
    if (!validateObjectName(objectName)) {
      return res.status(400).json({
        error: 'Invalid object name'
      });
    }

    if (!validateRecordId(recordId)) {
      return res.status(400).json({
        error: 'Invalid record ID'
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    await salesforceService.deleteRecord(objectName, recordId);

    analyticsService.recordEvent(`${objectName}_deleted`, {
      recordId
    });

    // Clear cache for this object
    cacheService.delete(`records_${objectName}`);

    res.json({
      message: 'Record deleted',
      object: objectName,
      recordId
    });
  } catch (error) {
    analyticsService.recordEvent(`${objectName}_error`, {
      operation: 'delete',
      error: error.message
    });
    next(error);
  }
};

const queryRecords = async (req, res, next) => {
  try {
    const { query } = req.query;

    if (!query) {
      return res.status(400).json({
        error: 'query parameter is required'
      });
    }

    const salesforceService = new SalesforceService(
      req.user.accessToken,
      req.user.instanceUrl
    );

    const results = await salesforceService.queryRecords(query);

    analyticsService.recordEvent('soql_query', {
      recordsReturned: results.records?.length || 0
    });

    res.json({
      query,
      results
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getRecords,
  getRecord,
  createRecord,
  updateRecord,
  deleteRecord,
  queryRecords
};
