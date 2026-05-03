require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const pinoHttp = require('pino-http');
const session = require('express-session');
const passport = require('passport');

const authRoutes = require('./routes/auth');
const recordsRoutes = require('./routes/records');
const syncRoutes = require('./routes/sync');
const analyticsRoutes = require('./routes/analytics');
const systemRoutes = require('./routes/system');
const billingRoutes = require('./routes/billing');
const billingController = require('./controllers/billingController');

const errorHandler = require('./middleware/errorHandler');
const { logger } = require('./middleware/logger');
const { sentinelFlowConfig, getFoundationStatus } = require('./config/sentinelFlow');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(compression());

// CORS configuration
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? process.env.ALLOWED_ORIGINS?.split(',') 
    : '*',
  credentials: true
}));

// Logging
app.use(pinoHttp({ logger }));

// Billing webhooks require the original raw body for provider signature verification.
app.post('/api/billing/webhook', express.raw({ type: 'application/json' }), billingController.handleWebhook);

// Body parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'your-secret-key',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Passport initialization
app.use(passport.initialize());
app.use(passport.session());

// Routes
app.use('/auth', authRoutes);
app.use('/api/records', recordsRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/system', systemRoutes);
app.use('/api/billing', billingRoutes);

// ── Serve Static Sites ──────────────────────────────────────────────
const path = require('path');

// Serve the Marketing Website at the root (/)
app.use(express.static(path.join(__dirname, '../website')));

// Serve the SentinelFlow Dashboard at (/dashboard)
app.use('/dashboard', express.static(path.join(__dirname, 'dashboard')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    platform: sentinelFlowConfig.platform.shortName,
    phase: sentinelFlowConfig.platform.phase,
    readiness: getFoundationStatus(),
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    method: req.method
  });
});

// Error handling middleware
app.use(errorHandler);

const startServer = () => {
  const server = app.listen(PORT, () => {
    logger.info(`${sentinelFlowConfig.platform.shortName} server running on port ${PORT}`);
    logger.info({
      environment: process.env.NODE_ENV || 'development',
      phase: sentinelFlowConfig.platform.phase
    }, 'Application context');
  });

  process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    server.close(() => {
      logger.info('Server closed');
      process.exit(0);
    });
  });

  process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    server.close(() => {
      logger.info('Server closed');
      process.exit(0);
    });
  });

  return server;
};

if (require.main === module) {
  startServer();
}

module.exports = {
  app,
  startServer
};
