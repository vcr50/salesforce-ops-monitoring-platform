const analyticsService = require('../services/analyticsService');

const getDashboard = (req, res, next) => {
  try {
    const { objectName } = req.query;

    if (objectName) {
      const dashboard = analyticsService.getDashboardData(objectName);
      return res.json(dashboard);
    }

    // Return summary for all tracked objects
    const metrics = analyticsService.getMetrics();
    const objectNames = new Set();

    Object.keys(metrics).forEach(eventName => {
      const parts = eventName.split('_');
      if (parts.length > 1) {
        objectNames.add(parts[0]);
      }
    });

    const dashboards = Array.from(objectNames).map(objName => 
      analyticsService.getDashboardData(objName)
    );

    res.json({
      title: 'Analytics Dashboard',
      generatedAt: new Date(),
      dashboards,
      totalMetrics: dashboards.reduce((sum, d) => sum + d.metrics.totalRecords, 0)
    });
  } catch (error) {
    next(error);
  }
};

const getObjectAnalytics = (req, res, next) => {
  try {
    const { objectName } = req.params;

    if (!objectName) {
      return res.status(400).json({
        error: 'objectName is required'
      });
    }

    const metrics = analyticsService.getObjectMetrics(objectName);
    const events = analyticsService.getMetrics(`${objectName}_created`);

    res.json({
      object: objectName,
      metrics,
      recentEvents: events.slice(-10)
    });
  } catch (error) {
    next(error);
  }
};

const generateReport = (req, res, next) => {
  try {
    const { startDate, endDate, objectName } = req.query;

    const filters = {};
    if (startDate) filters.startDate = startDate;
    if (endDate) filters.endDate = endDate;
    if (objectName) filters.objectName = objectName;

    const report = analyticsService.generateReport(filters);

    res.json({
      title: 'Analytics Report',
      ...report
    });
  } catch (error) {
    next(error);
  }
};

const recordEvent = (req, res, next) => {
  try {
    const { eventName, data } = req.body;

    if (!eventName) {
      return res.status(400).json({
        error: 'eventName is required'
      });
    }

    analyticsService.recordEvent(eventName, data || {});

    res.status(201).json({
      message: 'Event recorded',
      eventName,
      timestamp: new Date()
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getDashboard,
  getObjectAnalytics,
  generateReport,
  recordEvent
};
