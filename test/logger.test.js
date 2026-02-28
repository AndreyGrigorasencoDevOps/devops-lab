const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

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
  const config = loadLoggerWithEnv('development')

  assert.equal(config.level, 'debug')
  assert.ok(config.transport)
  assert.equal(config.transport.target, 'pino-pretty')
  assert.equal(config.transport.options.colorize, true)
})

test('logger: production disables transport', () => {
  const config = loadLoggerWithEnv('production')

  assert.equal(config.level, 'debug')
  assert.equal(config.transport, undefined)
})
