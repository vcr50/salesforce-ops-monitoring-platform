const { logger } = require('../middleware/logger');
const { v4: uuidv4 } = require('uuid');

class DataSyncService {
  constructor() {
    this.syncSessions = new Map();
    this.syncLogs = [];
  }

  startSync(objectName, direction = 'bidirectional') {
    const sessionId = uuidv4();
    const session = {
      id: sessionId,
      objectName,
      direction, // 'to-salesforce', 'from-salesforce', 'bidirectional'
      status: 'in-progress',
      startTime: new Date(),
      endTime: null,
      recordsProcessed: 0,
      recordsFailed: 0,
      error: null
    };

    this.syncSessions.set(sessionId, session);
    logger.info(`Started sync session ${sessionId} for ${objectName}`);

    return session;
  }

  updateSync(sessionId, updates) {
    const session = this.syncSessions.get(sessionId);
    if (!session) {
      throw new Error(`Sync session ${sessionId} not found`);
    }

    Object.assign(session, updates);
    return session;
  }

  completeSync(sessionId, success = true, error = null) {
    const session = this.syncSessions.get(sessionId);
    if (!session) {
      throw new Error(`Sync session ${sessionId} not found`);
    }

    session.status = success ? 'completed' : 'failed';
    session.endTime = new Date();
    session.error = error;

    this.syncLogs.push({
      ...session,
      duration: session.endTime - session.startTime
    });

    logger.info(`Completed sync session ${sessionId}: ${session.status}`);
    return session;
  }

  getSyncStatus(sessionId) {
    return this.syncSessions.get(sessionId) || null;
  }

  getSyncLogs(filter = {}) {
    let logs = [...this.syncLogs];

    if (filter.objectName) {
      logs = logs.filter(log => log.objectName === filter.objectName);
    }

    if (filter.status) {
      logs = logs.filter(log => log.status === filter.status);
    }

    if (filter.limit) {
      logs = logs.slice(-filter.limit);
    }

    return logs;
  }

  // Transform records for sync
  transformRecordsToSalesforce(records) {
    return records.map(record => ({
      ...record,
      // Add transformation logic as needed
      LastSyncTimestamp__c: new Date().toISOString()
    }));
  }

  transformRecordsFromSalesforce(records) {
    return records.map(record => ({
      ...record,
      // Remove Salesforce internal fields
      attributes: undefined,
      Id: undefined,
      // Add transformation logic as needed
      synced_at: new Date().toISOString()
    }));
  }

  // Conflict resolution
  resolveConflict(localRecord, remoteRecord, strategy = 'remote-wins') {
    if (strategy === 'remote-wins') {
      return remoteRecord;
    } else if (strategy === 'local-wins') {
      return localRecord;
    } else if (strategy === 'merge') {
      return { ...localRecord, ...remoteRecord };
    } else if (strategy === 'newer-wins') {
      const localTime = new Date(localRecord.updatedAt);
      const remoteTime = new Date(remoteRecord.LastModifiedDate);
      return localTime > remoteTime ? localRecord : remoteRecord;
    }

    return remoteRecord; // default
  }
}

module.exports = new DataSyncService();
