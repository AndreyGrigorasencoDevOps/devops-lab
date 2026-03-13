process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')

function loadDbModule() {
  const poolConfigs = []
  const pools = []
  const loggerState = {
    infoCalls: [],
    errorCalls: [],
  }

  function Pool(config) {
    poolConfigs.push(config)

    const handlers = {}
    const fakePool = {
      handlers,
      on(event, handler) {
        handlers[event] = handler
      }
    }

    pools.push(fakePool)
    return fakePool
  }

  const fakeLogger = {
    info(...args) {
      loggerState.infoCalls.push(args)
    },
    error(...args) {
      loggerState.errorCalls.push(args)
    }
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
    exports: { Pool }
  }
  require.cache[loggerPath] = {
    id: loggerPath,
    filename: loggerPath,
    loaded: true,
    exports: fakeLogger
  }

  const db = require('../src/config/db')

  function restore() {
    delete require.cache[dbPath]

    if (savedPg) {
      require.cache[pgPath] = savedPg
    } else {
      delete require.cache[pgPath]
    }

    if (savedLogger) {
      require.cache[loggerPath] = savedLogger
    } else {
      delete require.cache[loggerPath]
    }
  }

  poolConfigs.length = 0
  pools.length = 0
  loggerState.infoCalls.length = 0
  loggerState.errorCalls.length = 0

  return { db, poolConfigs, pools, loggerState, restore }
}

test('db config: createPool registers handlers and uses local defaults without SSL', () => {
  const ctx = loadDbModule()

  try {
    ctx.db.createPool({
      DB_HOST: '127.0.0.1',
      DB_USER: 'postgres',
      DB_PASSWORD: 'postgres',
      DB_NAME: 'taskdb',
    })

    assert.equal(ctx.poolConfigs.length, 1)
    assert.deepEqual(ctx.poolConfigs[0], {
      host: '127.0.0.1',
      user: 'postgres',
      password: 'postgres',
      database: 'taskdb',
      port: 5432,
    })

    const createdPool = ctx.pools[0]
    assert.ok(createdPool.handlers.connect, 'connect handler registered')
    assert.ok(createdPool.handlers.error, 'error handler registered')

    createdPool.handlers.connect()
    assert.equal(ctx.loggerState.infoCalls.length, 1)

    const originalExit = process.exit
    let exitCode = null
    process.exit = (code) => { exitCode = code }

    try {
      createdPool.handlers.error(new Error('boom'))
      assert.equal(ctx.loggerState.errorCalls.length, 1)
      assert.equal(exitCode, 1)
    } finally {
      process.exit = originalExit
    }
  } finally {
    ctx.restore()
  }
})

test('db config: createPool enables TLS automatically for Azure PostgreSQL hosts', () => {
  const ctx = loadDbModule()

  try {
    ctx.db.createPool({
      DB_HOST: 'taskapi-dev-pg.postgres.database.azure.com',
      DB_USER: 'taskapipg',
      DB_PASSWORD: 'secret',
      DB_NAME: 'taskdb',
      DB_PORT: '5432',
    })

    assert.deepEqual(ctx.poolConfigs[0], {
      host: 'taskapi-dev-pg.postgres.database.azure.com',
      user: 'taskapipg',
      password: 'secret',
      database: 'taskdb',
      port: 5432,
      ssl: {
        rejectUnauthorized: false,
      },
    })
  } finally {
    ctx.restore()
  }
})

test('db config: explicit DB_SSL=disable overrides automatic Azure TLS', () => {
  const ctx = loadDbModule()

  try {
    ctx.db.createPool({
      DB_HOST: 'taskapi-dev-pg.postgres.database.azure.com',
      DB_USER: 'taskapipg',
      DB_PASSWORD: 'secret',
      DB_NAME: 'taskdb',
      DB_SSL: 'disable',
    })

    assert.deepEqual(ctx.poolConfigs[0], {
      host: 'taskapi-dev-pg.postgres.database.azure.com',
      user: 'taskapipg',
      password: 'secret',
      database: 'taskdb',
      port: 5432,
    })
  } finally {
    ctx.restore()
  }
})

test('db config: resolveSslConfig honors DB_SSL_REJECT_UNAUTHORIZED true/false/fallback', () => {
  const ctx = loadDbModule()

  try {
    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'require',
        DB_SSL_REJECT_UNAUTHORIZED: 'true',
      }),
      { rejectUnauthorized: true }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'require',
        DB_SSL_REJECT_UNAUTHORIZED: 'off',
      }),
      { rejectUnauthorized: false }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'require',
        DB_SSL_REJECT_UNAUTHORIZED: 'maybe',
      }),
      { rejectUnauthorized: false }
    )
  } finally {
    ctx.restore()
  }
})

test('db config: resolveSslConfig uses strict defaults for verify-ca and verify-full', () => {
  const ctx = loadDbModule()

  try {
    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'verify-ca',
      }),
      { rejectUnauthorized: true }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        PGSSLMODE: 'verify-full',
      }),
      { rejectUnauthorized: true }
    )
  } finally {
    ctx.restore()
  }
})
