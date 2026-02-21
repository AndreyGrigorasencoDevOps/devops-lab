const express = require('express');
const tasksRouter = require('./routes/tasks.routes');
const httpLogger = require('./middlewares/httpLogger');
const errorHandler = require('./middlewares/errorHandler');
const { checkDatabase } = require('./services/readiness.service');
const logger = require('./utils/logger');

// Load .env only in non-production environments
if (process.env.NODE_ENV !== "production") {
  try {
    require("dotenv").config();
  } catch {
    // dotenv is optional; ignore if not installed
    logger.debug("dotenv not loaded (optional)");
  }
}

require('./config/db');

const app = express();
app.disable('x-powered-by');

app.use(express.json());
app.use(httpLogger);

// Liveness
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: process.env.SERVICE_NAME || 'node-api' });
});

// Readiness
app.get('/ready', async (req, res) => {
  try {
    await checkDatabase();
    res.json({ status: 'ready', service: process.env.SERVICE_NAME || 'node-api' });
  } catch (err) {
    logger.error({ err }, 'Readiness check failed');

    res.status(503).json({
      status: 'not_ready',
      service: process.env.SERVICE_NAME || 'node-api',
    });
  }
});

// Info
app.get('/info', (req, res) => {
  res.json({
    service: process.env.SERVICE_NAME || 'node-api',
    port: process.env.PORT ? Number(process.env.PORT) : 3000,
    node: process.version,
    uptimeSec: Math.floor(process.uptime()),
  });
});

app.use('/tasks', tasksRouter);

app.use(errorHandler);

module.exports = app;