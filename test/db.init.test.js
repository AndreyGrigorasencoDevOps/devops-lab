process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

test('initDB: runs schema creation query inside retry and logs success', async () => {
  let queryCalled = false
  let receivedSql = null

  const pool = {
    async query(sql) {
      queryCalled = true
      receivedSql = sql
    }
  }

  let retryCalled = false
  const retry = async (fn) => {
    retryCalled = true
    await fn()
  }

  let infoCalled = false
  let infoPayload = null
  let infoMsg = null

  const logger = {
    info(payload, msg) {
      infoCalled = true
      infoPayload = payload
      infoMsg = msg
    }
  }

  const initDB = proxyquire('../src/db/init', {
    '../config/db': pool,
    '../utils/retry': retry,
    '../utils/logger': logger
  })

  await initDB()

  assert.equal(retryCalled, true)
  assert.equal(queryCalled, true)

  assert.ok(typeof receivedSql === 'string')
  assert.ok(receivedSql.includes('CREATE TABLE IF NOT EXISTS tasks'))

  assert.equal(infoCalled, true)
  assert.equal(infoMsg, 'Database initialized')
  assert.ok(infoPayload && typeof infoPayload === 'object')
  assert.ok('service' in infoPayload)
})
