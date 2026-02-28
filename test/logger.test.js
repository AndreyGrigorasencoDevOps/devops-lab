const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

const savedNodeEnv = process.env.NODE_ENV
const savedLogLevel = process.env.LOG_LEVEL

function loadLoggerWithEnv(env) {
  delete require.cache[require.resolve('../src/utils/logger')]

  const capturedConfigs = []

  const fakePino = (config) => {
    capturedConfigs.push(config)
    return { fake: true }
  }

  process.env.NODE_ENV = env
  process.env.LOG_LEVEL = 'debug'

  proxyquire('../src/utils/logger', {
    pino: fakePino
  })

  return capturedConfigs[0]
}

test('logger: non-production enables pino-pretty transport', () => {
  try {
    const config = loadLoggerWithEnv('development')

    assert.equal(config.level, 'debug')
    assert.ok(config.transport)
    assert.equal(config.transport.target, 'pino-pretty')
    assert.equal(config.transport.options.colorize, true)
  } finally {
    process.env.NODE_ENV = savedNodeEnv
    process.env.LOG_LEVEL = savedLogLevel
  }
})

test('logger: production disables transport', () => {
  try {
    const config = loadLoggerWithEnv('production')

    assert.equal(config.level, 'debug')
    assert.equal(config.transport, undefined)
  } finally {
    process.env.NODE_ENV = savedNodeEnv
    process.env.LOG_LEVEL = savedLogLevel
  }
})
