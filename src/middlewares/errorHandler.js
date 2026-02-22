const logger = require('../utils/logger')

module.exports = function errorHandler(err, req, res, next) {
  // If response already started, delegate to default Express handler
  if (res.headersSent) {
    return next(err)
  }

  const status =
    Number.isInteger(err.status) && err.status > 0
      ? err.status
      : Number.isInteger(err.statusCode) && err.statusCode > 0
        ? err.statusCode
        : 500

  const isServerError = status >= 500

  const logContext = {
    status,
    path: req.path,
    method: req.method
  }

  if (isServerError) {
    logger.error(
      {
        ...logContext,
        err: {
          message: err.message,
          stack: err.stack
        }
      },
      'Unhandled server error'
    )
  } else {
    logger.warn(
      {
        ...logContext,
        err: {
          message: err.message
        }
      },
      'Client error'
    )
  }

  const message = isServerError ? 'Internal Server Error' : err.message

  res.status(status).json({ error: message })
}