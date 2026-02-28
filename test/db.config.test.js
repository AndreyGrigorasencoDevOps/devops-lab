process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')

test('db config: createPool registers connect/error handlers', () => {
  let connectHandler
  let errorHandler

  const fakePool = {
    on(event, handler) {
      if (event === 'connect') { connectHandler = handler }
      if (event === 'error') { errorHandler = handler }
    }
  }

  let infoCalled = false
  let errorCalled = false

  const fakeLogger = {
    info() { infoCalled = true },
    error() { errorCalled = true }
  }

  const pgPath = require.resolve('pg')
  const loggerPath = require.resolve('../src/utils/logger')
  const dbPath = require.resolve('../src/config/db')

  const savedPg = require.cache[pgPath]
  const savedLogger = require.cache[loggerPath]
  delete require.cache[dbPath]

  require.cache[pgPath] = {
    id: pgPath,
    filename: pgPath,
    loaded: true,
    exports: { Pool: function Pool() { return fakePool } }
  }
  require.cache[loggerPath] = {
    id: loggerPath,
    filename: loggerPath,
    loaded: true,
    exports: fakeLogger
  }

  try {
    const db = require('../src/config/db')

    assert.ok(db)
    assert.equal(typeof db.createPool, 'function')

    assert.ok(connectHandler, 'connect handler registered')
    assert.ok(errorHandler, 'error handler registered')

    connectHandler()
    assert.equal(infoCalled, true)

    const originalExit = process.exit
    let exitCode = null
    process.exit = (code) => { exitCode = code }

    try {
      errorHandler(new Error('boom'))

      assert.equal(errorCalled, true)
      assert.equal(exitCode, 1)
    } finally {
      process.exit = originalExit
    }
  } finally {
    delete require.cache[dbPath]
    if (savedPg) { require.cache[pgPath] = savedPg } else { delete require.cache[pgPath] }
    if (savedLogger) { require.cache[loggerPath] = savedLogger } else { delete require.cache[loggerPath] }
  }
})
