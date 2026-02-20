const { Pool } = require("pg");
const logger = require("../utils/logger");

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432,
});

pool.on("connect", () => {
  logger.info("Connected to PostgreSQL");
});

pool.on("error", (err) => {
  logger.error({ err }, "Unexpected error on idle client");
  process.exit(1);
});

module.exports = pool;