const pool = require('../config/db')
const retry = require('../utils/retry')

async function initDB() {
  await retry(async () => {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL
      );
    `)
  })

  console.log('Database initialized')
}

module.exports = initDB