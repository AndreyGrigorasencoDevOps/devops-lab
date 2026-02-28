const { start } = require("./server");
const logger = require("./utils/logger");

const SERVICE_NAME = process.env.SERVICE_NAME || "node-api";

start().catch((err) => {
  logger.error({ err, service: SERVICE_NAME }, "Startup failed");
  process.exit(1);
});
