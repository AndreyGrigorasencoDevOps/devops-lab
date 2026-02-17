const app = require('./app')
const initDB = require('./db/init')

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000
const SERVICE_NAME = process.env.SERVICE_NAME || 'node-api'

async function start() {
  try {
    await initDB()

    // Bind to 0.0.0.0 to allow external access (required for Docker)
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`[${SERVICE_NAME}] Server running on port ${PORT}`)
    })
  } catch (err) {
    console.error(`[${SERVICE_NAME}] Startup failed`, err)
    process.exit(1)
  }
}

start()