const { Pool } = require('pg')

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432
})

pool.on('connect', () => {
  console.log('Connected to PostgreSQL')
})

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err)
  process.exit(1)
})

module.exports = pool