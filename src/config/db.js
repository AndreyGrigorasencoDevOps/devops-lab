require('./env')

const { Pool } = require("pg");
const logger = require("../utils/logger");

const AZURE_POSTGRES_HOST_SUFFIX = ".postgres.database.azure.com";

function resolveRejectUnauthorized(env, defaultValue) {
  const rawValue = env.DB_SSL_REJECT_UNAUTHORIZED;

  if (typeof rawValue !== "string") {
    return defaultValue;
  }

  const normalizedValue = rawValue.trim().toLowerCase();

  if (["true", "1", "yes", "on"].includes(normalizedValue)) {
    return true;
  }

  if (["false", "0", "no", "off"].includes(normalizedValue)) {
    return false;
  }

  return defaultValue;
}

function resolveSslConfig(env = process.env) {
  const sslMode = env.DB_SSL ?? env.PGSSLMODE;

  if (typeof sslMode === "string") {
    const normalizedMode = sslMode.trim().toLowerCase();

    if (["disable", "false", "0", "no", "off"].includes(normalizedMode)) {
      return undefined;
    }

    if (["require", "verify-ca", "verify-full", "true", "1", "yes", "on"].includes(normalizedMode)) {
      return {
        rejectUnauthorized: resolveRejectUnauthorized(
          env,
          normalizedMode === "verify-ca" || normalizedMode === "verify-full"
        ),
      };
    }
  }

  if (typeof env.DB_HOST === "string" && env.DB_HOST.endsWith(AZURE_POSTGRES_HOST_SUFFIX)) {
    return {
      rejectUnauthorized: resolveRejectUnauthorized(env, false),
    };
  }

  return undefined;
}

function createPool(env = process.env) {
  const poolConfig = {
    host: env.DB_HOST,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    port: env.DB_PORT ? Number(env.DB_PORT) : 5432,
  };
  const ssl = resolveSslConfig(env);

  if (ssl) {
    poolConfig.ssl = ssl;
  }

  const pool = new Pool(poolConfig);

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
module.exports.resolveSslConfig = resolveSslConfig;
