process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

test('checkDatabase: returns true when query succeeds', async () => {
  let queryCalled = false

  const pool = {
    async query(sql) {
      queryCalled = true
      assert.equal(sql, 'SELECT 1')
    }
  }

  const { checkDatabase } = proxyquire('../src/services/readiness.service', {
    '../config/db': pool
  })

  const result = await checkDatabase()

  assert.equal(queryCalled, true)
  assert.equal(result, true)
})

test('checkDatabase: throws if query fails', async () => {
  const pool = {
    async query() {
      throw new Error('DB down')
    }
  }

  const { checkDatabase } = proxyquire('../src/services/readiness.service', {
    '../config/db': pool
  })

  await assert.rejects(
    async () => {
      await checkDatabase()
    },
    { message: 'DB down' }
  )
})
