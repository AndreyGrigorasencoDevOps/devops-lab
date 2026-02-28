const logger = require('../utils/logger')

function resolveHttpStatus(err) {
  if (Number.isInteger(err.status) && err.status > 0) {
    return err.status
  }
  if (Number.isInteger(err.statusCode) && err.statusCode > 0) {
    return err.statusCode
  }
  return 500
}

module.exports = function errorHandler(err, req, res, next) {
  // If response already started, delegate to default Express handler
  if (res.headersSent) {
    return next(err)
  }

  const status = resolveHttpStatus(err)

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