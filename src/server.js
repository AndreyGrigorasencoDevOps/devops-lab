const app = require('./app')

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000
const SERVICE_NAME = process.env.SERVICE_NAME || 'node-api'

app.listen(PORT, () => {
  console.log(`[${SERVICE_NAME}] Server running on http://localhost:${PORT}`)
})