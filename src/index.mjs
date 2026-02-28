import { start } from "./server.js";
import logger from "./utils/logger.js";

const SERVICE_NAME = process.env.SERVICE_NAME || "node-api";

try {
  await start();
} catch (err) {
  logger.error({ err, service: SERVICE_NAME }, "Startup failed");
  process.exit(1);
}
