process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

test('start: calls initDB and starts listening', async () => {
  let initCalled = false
  let listenCalled = false

  const fakeServer = { close: (cb) => cb(null) }
  const app = {
    listen(port, host, cb) {
      listenCalled = true
      cb()
      return fakeServer
    }
  }

  const initDB = () => {
    initCalled = true
    return Promise.resolve()
  }

  const pool = { end: () => Promise.resolve() }
  const logger = { info() {}, error() {}, warn() {} }

  const serverModule = proxyquire('../src/server', {
    './app': app,
    './db/init': initDB,
    './config/db': pool,
    './utils/logger': logger
  })

  const srv = await serverModule.start()

  assert.equal(initCalled, true)
  assert.equal(listenCalled, true)
  assert.equal(srv, fakeServer)
})

test('shutdown: closes server and ends pool', async () => {
  let poolEnded = false
  const pool = {
    end() {
      poolEnded = true
      return Promise.resolve()
    }
  }
  const logger = { info() {}, error() {}, warn() {} }

  const fakeServer = {
    close(cb) {
      cb(null)
    }
  }

  const originalExit = process.exit
  let exitCode = null
  process.exit = (code) => { exitCode = code }

  const serverModule = proxyquire('../src/server', {
    './app': {
      listen(port, host, cb) {
        cb()
        return fakeServer
      }
    },
    './db/init': () => Promise.resolve(),
    './config/db': pool,
    './utils/logger': logger
  })

  await serverModule.start()
  await serverModule.shutdown('SIGTERM')

  process.exit = originalExit

  assert.equal(poolEnded, true)
  assert.equal(exitCode, 0)
})
