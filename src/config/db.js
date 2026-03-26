require('./env')

const { Pool } = require("pg");
const logger = require("../utils/logger");

const AZURE_POSTGRES_HOST_SUFFIX = ".postgres.database.azure.com";
const SSL_DISABLED_MODES = new Set(["disable", "false", "0", "no", "off"]);
const SSL_ENABLED_MODES = new Set(["require", "verify-ca", "verify-full", "true", "1", "yes", "on"]);

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

    if (SSL_DISABLED_MODES.has(normalizedMode)) {
      return { mode: "disabled" };
    }

    if (SSL_ENABLED_MODES.has(normalizedMode)) {
      return {
        mode: "enabled",
        rejectUnauthorized: resolveRejectUnauthorized(
          env,
          normalizedMode === "verify-ca" || normalizedMode === "verify-full"
        ),
      };
    }
  }

  if (typeof env.DB_HOST === "string" && env.DB_HOST.endsWith(AZURE_POSTGRES_HOST_SUFFIX)) {
    return {
      mode: "enabled",
      rejectUnauthorized: resolveRejectUnauthorized(env, false),
    };
  }

  return { mode: "inherit" };
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

  if (ssl.mode === "disabled") {
    poolConfig.ssl = false;
  } else if (ssl.mode === "enabled") {
    poolConfig.ssl = {
      rejectUnauthorized: ssl.rejectUnauthorized,
    };
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
