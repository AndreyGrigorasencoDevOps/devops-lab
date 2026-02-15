const SERVICE_NAME = process.env.SERVICE_NAME || 'node-api'
const LOG_LEVEL = process.env.LOG_LEVEL || 'info'

module.exports = function logger(req, res, next) {
  const start = Date.now()

  res.on('finish', () => {
    const durationMs = Date.now() - start
    if (LOG_LEVEL !== 'silent') {
      console.log(
        `[${SERVICE_NAME}] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${durationMs}ms)`
      )
    }
  })

  next()
}