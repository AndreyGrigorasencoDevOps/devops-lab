process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

function loadServer({ initSucceeds = true, closeFails = false } = {}) {
  delete require.cache[require.resolve('../src/server')]

  let closeCalled = false
  let poolEndCalled = false
  let listenCalled = false
  let exitCode = null

  const fakeServer = {
    close(cb) {
      closeCalled = true
      if (closeFails) { cb(new Error('close fail')) } else { cb() }
    }
  }

  const app = {
    listen(port, host, cb) {
      listenCalled = true
      cb()
      return fakeServer
    }
  }

  const initDB = () => {
    if (!initSucceeds) { return Promise.reject(new Error('init fail')) }
    return Promise.resolve()
  }

  const pool = {
    async end() {
      poolEndCalled = true
    }
  }

  const logger = {
    info() {},
    error() {}
  }

  const originalExit = process.exit
  process.exit = (code) => { exitCode = code }

  const originalOn = process.on
  process.on = () => {}

  const serverModule = proxyquire('../src/server', {
    './app': app,
    './db/init': initDB,
    './config/db': pool,
    './utils/logger': logger
  })

  return {
    serverModule,
    restore() {
      process.exit = originalExit
      process.on = originalOn
    },
    getState() {
      return { closeCalled, poolEndCalled, listenCalled, exitCode }
    }
  }
}

test('start: initializes DB and starts server', async () => {
  const ctx = loadServer({ initSucceeds: true })

  const server = await ctx.serverModule.start()

  const state = ctx.getState()

  assert.ok(server)
  assert.equal(state.listenCalled, true)

  ctx.restore()
})

test('shutdown: closes server and DB pool', async () => {
  const ctx = loadServer({ initSucceeds: true })

  await ctx.serverModule.start()
  await ctx.serverModule.shutdown('SIGTERM')

  const state = ctx.getState()

  assert.equal(state.closeCalled, true)
  assert.equal(state.poolEndCalled, true)
  assert.equal(state.exitCode, 0)

  ctx.restore()
})

test('shutdown: handles close failure', async () => {
  const ctx = loadServer({ initSucceeds: true, closeFails: true })

  await ctx.serverModule.start()
  await ctx.serverModule.shutdown('SIGTERM')

  const state = ctx.getState()

  assert.equal(state.exitCode, 1)

  ctx.restore()
})

test('start: rejects if initDB fails', async () => {
  const ctx = loadServer({ initSucceeds: false })

  await assert.rejects(
    async () => { await ctx.serverModule.start() },
    { message: 'init fail' }
  )

  ctx.restore()
})
