const app = require("./app");
const initDB = require("./db/init");
const pool = require("./config/db");
const logger = require("./utils/logger");

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || "node-api";

let server;

async function start() {
  try {
    await initDB();

    // Bind to 0.0.0.0 to allow external access (required for Docker)
    server = app.listen(PORT, "0.0.0.0", () => {
      logger.info({ service: SERVICE_NAME, port: PORT }, "Server started");
    });
  } catch (err) {
    logger.error({ err, service: SERVICE_NAME }, "Startup failed");
    process.exit(1);
  }
}

async function shutdown(signal) {
  logger.info(
    { service: SERVICE_NAME, signal },
    "Received signal. Starting graceful shutdown..."
  );

  try {
    if (server) {
      await new Promise((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
      logger.info({ service: SERVICE_NAME }, "HTTP server closed");
    }

    await pool.end();
    logger.info({ service: SERVICE_NAME }, "Database pool closed");

    process.exit(0);
  } catch (err) {
    logger.error({ err, service: SERVICE_NAME }, "Graceful shutdown failed");
    process.exit(1);
  }
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

start();