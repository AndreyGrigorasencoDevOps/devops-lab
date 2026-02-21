const logger = require('../utils/logger')

module.exports = function errorHandler(err, req, res, _next) {
  const status =
    Number.isInteger(err.status) && err.status > 0
      ? err.status
      : 500

  const isServerError = status >= 500

  // Log level based on error type
  if (isServerError) {
    logger.error(
      { err, path: req.path, status },
      'Unhandled server error'
    )
  } else {
    logger.warn(
      { err: { message: err.message }, path: req.path, status },
      'Client error'
    )
  }

  const message =
    isServerError
      ? 'Internal Server Error'
      : err.message

  res.status(status).json({ error: message })
}