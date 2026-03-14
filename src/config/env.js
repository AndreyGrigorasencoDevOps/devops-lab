if (process.env.NODE_ENV !== 'production') {
  try {
    require('dotenv').config()
  } catch {
    // dotenv is optional for runtime environments that inject env vars directly.
  }
}

module.exports = process.env
