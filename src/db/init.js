const pool = require('../config/db')

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL
    )
  `)
  console.log('Tasks table ready')
}

module.exports = initDB