const { Pool } = require("pg");
const logger = require("../utils/logger");

function createPool(env = process.env) {
  const pool = new Pool({
    host: env.DB_HOST,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    port: 5432,
  });

  pool.on("connect", () => {
    logger.info("Connected to PostgreSQL");
  });

  pool.on("error", (err) => {
    logger.error({ err }, "Unexpected error on idle client");
    process.exit(1);
  });

  return pool;
}

const pool = createPool();

module.exports = pool;
module.exports.createPool = createPool;
