const pool = require("../config/db");
const retry = require("../utils/retry");
const logger = require("../utils/logger");

const SERVICE_NAME = process.env.SERVICE_NAME || "node-api";

async function initDB() {
  await retry(async () => {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL
      );
    `);
  });

  logger.info({ service: SERVICE_NAME }, "Database initialized");
}

module.exports = initDB;