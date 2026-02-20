const logger = require("../utils/logger");

async function retry(fn, retries = 5, delay = 2000) {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (err) {
      logger.warn(
        {
          attempt: i + 1,
          retries,
          delay,
          err,
        },
        "Retry attempt failed"
      );

      if (i === retries - 1) {
        logger.error({ err }, "All retry attempts failed");
        throw err;
      }

      await new Promise((res) => setTimeout(res, delay));
    }
  }
}

module.exports = retry;