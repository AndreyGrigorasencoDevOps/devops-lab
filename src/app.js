const express = require('express')
const tasksRouter = require('./routes/tasks.routes')
const logger = require('./middlewares/logger')
const errorHandler = require('./middlewares/errorHandler')
const { checkDatabase } = require('./services/readiness.service')

// Load .env only in non-production environments (local development)
if (process.env.NODE_ENV !== 'production') {
  try {
    require('dotenv').config()
  } catch (err) {
    // dotenv is optional; ignore if not installed
  }
}
// DB init
require('./config/db')

const app = express()

app.use(express.json())
app.use(logger)

// Liveness
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: process.env.SERVICE_NAME || 'node-api' })
})

// Readiness
app.get('/ready', async (req, res) => {
  try {
    await checkDatabase()
    res.json({ status: 'ready', service: process.env.SERVICE_NAME || 'node-api' })
  } catch (err) {
    res.status(503).json({
      status: 'not_ready',
      service: process.env.SERVICE_NAME || 'node-api'
    })
  }
})

// Info
app.get('/info', (req, res) => {
  res.json({
    service: process.env.SERVICE_NAME || 'node-api',
    port: process.env.PORT ? Number(process.env.PORT) : 3000,
    node: process.version,
    uptimeSec: Math.floor(process.uptime())
  })
})

app.use('/tasks', tasksRouter)

// error middleware
app.use(errorHandler)

module.exports = app