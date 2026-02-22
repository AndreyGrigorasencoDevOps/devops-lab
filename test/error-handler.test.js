process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const express = require('express')
const request = require('supertest')
const proxyquire = require('proxyquire')

test('errorHandler returns 500 with generic message and logs error', async () => {
  let errorCalls = 0
  let warnCalls = 0
  let lastErrorArgs
  let lastWarnArgs

  const loggerStub = {
    error: (...args) => { errorCalls += 1; lastErrorArgs = args },
    warn: (...args) => { warnCalls += 1; lastWarnArgs = args }
  }

  const errorHandler = proxyquire('../src/middlewares/errorHandler', {
    '../utils/logger': loggerStub
  })

  const app = express()

  app.get('/boom', (req, res, next) => {
    next(new Error('boom'))
  })

  app.use(errorHandler)

  const res = await request(app).get('/boom').expect(500)
  assert.deepEqual(res.body, { error: 'Internal Server Error' })

  assert.equal(errorCalls, 1)
  assert.equal(warnCalls, 0)

  assert.equal(lastErrorArgs[1], 'Unhandled server error')
  assert.equal(lastErrorArgs[0].status, 500)
  assert.equal(lastErrorArgs[0].path, '/boom')
  assert.equal(lastErrorArgs[0].method, 'GET')
  assert.equal(lastErrorArgs[0].err.message, 'boom')
  assert.ok(typeof lastErrorArgs[0].err.stack === 'string')
  assert.equal(lastWarnArgs, undefined)
})

test('errorHandler returns 4xx message and logs warn', async () => {
  let errorCalls = 0
  let warnCalls = 0
  let lastErrorArgs
  let lastWarnArgs

  const loggerStub = {
    error: (...args) => { errorCalls += 1; lastErrorArgs = args },
    warn: (...args) => { warnCalls += 1; lastWarnArgs = args }
  }

  const errorHandler = proxyquire('../src/middlewares/errorHandler', {
    '../utils/logger': loggerStub
  })

  const app = express()

  app.get('/bad', (req, res, next) => {
    const err = new Error('Bad Request')
    err.status = 400
    next(err)
  })

  app.use(errorHandler)

  const res = await request(app).get('/bad').expect(400)
  assert.deepEqual(res.body, { error: 'Bad Request' })

  assert.equal(warnCalls, 1)
  assert.equal(errorCalls, 0)

  assert.equal(lastWarnArgs[1], 'Client error')
  assert.equal(lastWarnArgs[0].status, 400)
  assert.equal(lastWarnArgs[0].path, '/bad')
  assert.equal(lastWarnArgs[0].method, 'GET')
  assert.equal(lastWarnArgs[0].err.message, 'Bad Request')
  assert.equal(lastErrorArgs, undefined)
})