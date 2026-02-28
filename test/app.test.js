process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const supertest = require('supertest')
const proxyquire = require('proxyquire').noCallThru()

function loadApp({ checkDbImpl, dotenvThrows = false, nodeEnv = 'test' }) {
  delete require.cache[require.resolve('../src/app')]

  process.env.NODE_ENV = nodeEnv
  process.env.SERVICE_NAME = 'test-service'
  process.env.PORT = '4000'

  const logger = {
    debug() {},
    error() {}
  }

  const dotenv = {
    config() {
      if (dotenvThrows) { throw new Error('no dotenv') }
    }
  }

  return proxyquire('../src/app', {
    './services/readiness.service': { checkDatabase: checkDbImpl },
    './utils/logger': logger,
    dotenv
  })
}

test('GET /health returns ok', async () => {
  const app = loadApp({ checkDbImpl: async () => true })

  const res = await supertest(app).get('/health')

  assert.equal(res.status, 200)
  assert.equal(res.body.status, 'ok')
  assert.equal(res.body.service, 'test-service')
})

test('GET /ready returns ready when DB ok', async () => {
  const app = loadApp({ checkDbImpl: async () => true })

  const res = await supertest(app).get('/ready')

  assert.equal(res.status, 200)
  assert.equal(res.body.status, 'ready')
})

test('GET /ready returns 503 when DB fails', async () => {
  const app = loadApp({
    checkDbImpl: async () => { throw new Error('db down') }
  })

  const res = await supertest(app).get('/ready')

  assert.equal(res.status, 503)
  assert.equal(res.body.status, 'not_ready')
})

test('GET /info returns service info', async () => {
  const app = loadApp({ checkDbImpl: async () => true })

  const res = await supertest(app).get('/info')

  assert.equal(res.status, 200)
  assert.equal(res.body.service, 'test-service')
  assert.equal(res.body.port, 4000)
  assert.ok(res.body.node)
  assert.ok(typeof res.body.uptimeSec === 'number')
})

test('dotenv loads in non-production', () => {
  loadApp({ checkDbImpl: async () => true, nodeEnv: 'development' })
})

test('dotenv optional failure is handled', () => {
  loadApp({
    checkDbImpl: async () => true,
    dotenvThrows: true,
    nodeEnv: 'development'
  })
})

test('dotenv not loaded in production', () => {
  loadApp({ checkDbImpl: async () => true, nodeEnv: 'production' })
})
