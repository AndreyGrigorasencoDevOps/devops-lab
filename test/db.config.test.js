process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

test('db config: registers connect handler and logs', () => {
  let connectHandler
  let errorHandler

  const fakePool = {
    on(event, handler) {
      if (event === 'connect') { connectHandler = handler }
      if (event === 'error') { errorHandler = handler }
    }
  }

  function Pool() {
    return fakePool
  }

  let infoCalled = false
  let errorCalled = false

  const logger = {
    info() { infoCalled = true },
    error() { errorCalled = true }
  }

  const db = proxyquire('../src/config/db', {
    pg: { Pool },
    '../utils/logger': logger
  })

  assert.equal(typeof db.createPool, 'function')

  connectHandler()
  assert.equal(infoCalled, true)

  const originalExit = process.exit
  let exitCode = null
  process.exit = (code) => { exitCode = code }

  errorHandler(new Error('boom'))

  process.exit = originalExit

  assert.equal(errorCalled, true)
  assert.equal(exitCode, 1)
})
