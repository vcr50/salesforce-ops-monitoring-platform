const { logger } = require('../middleware/logger');

class AnalyticsService {
  constructor() {
    this.metrics = new Map();
  }

  recordEvent(eventName, data = {}) {
    const event = {
      name: eventName,
      timestamp: new Date(),
      ...data
    };

    if (!this.metrics.has(eventName)) {
      this.metrics.set(eventName, []);
    }

    this.metrics.get(eventName).push(event);
    logger.debug(`Recorded event: ${eventName}`);
  }

  getMetrics(eventName = null) {
    if (eventName) {
      return this.metrics.get(eventName) || [];
    }

    // Return all metrics
    const allMetrics = {};
    this.metrics.forEach((value, key) => {
      allMetrics[key] = value;
    });
    return allMetrics;
  }

  getObjectMetrics(objectName) {
    const metrics = {
      objectName,
      totalRecords: 0,
      createdCount: 0,
      updatedCount: 0,
      deletedCount: 0,
      errorCount: 0
    };

    const events = this.metrics.get(`${objectName}_created`) || [];
    metrics.createdCount = events.length;

    const updateEvents = this.metrics.get(`${objectName}_updated`) || [];
    metrics.updatedCount = updateEvents.length;

    const deleteEvents = this.metrics.get(`${objectName}_deleted`) || [];
    metrics.deletedCount = deleteEvents.length;

    const errorEvents = this.metrics.get(`${objectName}_error`) || [];
    metrics.errorCount = errorEvents.length;

    metrics.totalRecords = metrics.createdCount + metrics.updatedCount + metrics.deletedCount;

    return metrics;
  }

  generateReport(filters = {}) {
    const report = {
      generatedAt: new Date(),
      totalEvents: 0,
      eventSummary: {},
      filters
    };

    this.metrics.forEach((events, eventName) => {
      let filteredEvents = events;

      if (filters.startDate) {
        filteredEvents = filteredEvents.filter(e => new Date(e.timestamp) >= new Date(filters.startDate));
      }

      if (filters.endDate) {
        filteredEvents = filteredEvents.filter(e => new Date(e.timestamp) <= new Date(filters.endDate));
      }

      report.eventSummary[eventName] = {
        count: filteredEvents.length,
        firstEvent: filteredEvents[0]?.timestamp,
        lastEvent: filteredEvents[filteredEvents.length - 1]?.timestamp
      };

      report.totalEvents += filteredEvents.length;
    });

    return report;
  }

  getDashboardData(objectName) {
    const metrics = this.getObjectMetrics(objectName);
    
    return {
      title: `${objectName} Analytics Dashboard`,
      generatedAt: new Date(),
      metrics,
      summary: {
        successRate: metrics.totalRecords > 0 
          ? ((metrics.totalRecords - metrics.errorCount) / metrics.totalRecords * 100).toFixed(2) + '%'
          : 'N/A',
        totalOperations: metrics.totalRecords + metrics.errorCount,
        totalErrors: metrics.errorCount
      }
    };
  }

  clearMetrics(eventName = null) {
    if (eventName) {
      this.metrics.delete(eventName);
      logger.info(`Cleared metrics for ${eventName}`);
    } else {
      this.metrics.clear();
      logger.info(`Cleared all metrics`);
    }
  }
}

module.exports = new AnalyticsService();
