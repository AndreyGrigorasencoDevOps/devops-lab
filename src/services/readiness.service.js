const pool = require('../config/db')

async function checkDatabase() {
  // Lightweight connectivity check
  await pool.query('SELECT 1')
  return true
}

module.exports = { checkDatabase }