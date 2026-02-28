process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

function loadRetryWithLogger(logger) {
  return proxyquire('../src/utils/retry', {
    '../utils/logger': logger
  })
}

test('retry: returns result on first success without logging', async () => {
  const logger = {
    warn: () => assert.fail('warn should not be called'),
    error: () => assert.fail('error should not be called')
  }

  const retry = loadRetryWithLogger(logger)

  const result = await retry(async () => 'ok', 3, 0)

  assert.equal(result, 'ok')
})

test('retry: logs warn on failure then succeeds', async () => {
  let attempts = 0
  let warnCalls = 0
  let errorCalls = 0

  const logger = {
    warn(meta) {
      warnCalls += 1
      assert.equal(typeof meta.attempt, 'number')
      assert.equal(typeof meta.retries, 'number')
      assert.equal(typeof meta.delay, 'number')
      assert.ok(meta.err instanceof Error)
    },
    error() {
      errorCalls += 1
    }
  }

  const retry = loadRetryWithLogger(logger)

  const result = await retry(
    async () => {
      attempts += 1
      if (attempts === 1) { throw new Error('boom') }
      return 'ok'
    },
    3,
    0
  )

  assert.equal(result, 'ok')
  assert.equal(warnCalls, 1)
  assert.equal(errorCalls, 0)
})

test('retry: throws after last retry and logs error', async () => {
  let warnCalls = 0
  let errorCalls = 0

  const logger = {
    warn() {
      warnCalls += 1
    },
    error(meta, msg) {
      errorCalls += 1
      assert.equal(msg, 'All retry attempts failed')
      assert.ok(meta && meta.err instanceof Error)
    }
  }

  const retry = loadRetryWithLogger(logger)

  await assert.rejects(
    async () => {
      await retry(async () => {
        throw new Error('still down')
      }, 3, 0)
    },
    { message: 'still down' }
  )

  assert.equal(warnCalls, 3)
  assert.equal(errorCalls, 1)
})
