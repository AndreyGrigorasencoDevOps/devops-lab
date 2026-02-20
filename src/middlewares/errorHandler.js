const logger = require('../utils/logger');

module.exports = function errorHandler(err, req, res, _next) {
  const status =
    err.status && Number.isInteger(err.status)
      ? err.status
      : 500;

  logger.error({ err, path: req.path }, 'Unhandled error');

  const message =
    status === 500
      ? 'Internal Server Error'
      : err.message;

  res.status(status).json({ error: message });
};