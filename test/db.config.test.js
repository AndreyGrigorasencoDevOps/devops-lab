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
  const dotenvPath = require.resolve('dotenv')
  const loggerPath = require.resolve('../src/utils/logger')
  const envPath = require.resolve('../src/config/env')
  const dbPath = require.resolve('../src/config/db')

  const savedPg = require.cache[pgPath]
  const savedDotenv = require.cache[dotenvPath]
  const savedLogger = require.cache[loggerPath]
  const savedEnv = require.cache[envPath]

  delete require.cache[envPath]
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
    delete require.cache[envPath]
    delete require.cache[dbPath]

    if (savedPg) {
      require.cache[pgPath] = savedPg
    } else {
      delete require.cache[pgPath]
    }

    if (savedDotenv) {
      require.cache[dotenvPath] = savedDotenv
    } else {
      delete require.cache[dotenvPath]
    }

    if (savedLogger) {
      require.cache[loggerPath] = savedLogger
    } else {
      delete require.cache[loggerPath]
    }

    if (savedEnv) {
      require.cache[envPath] = savedEnv
    } else {
      delete require.cache[envPath]
    }
  }

  poolConfigs.length = 0
  pools.length = 0
  loggerState.infoCalls.length = 0
  loggerState.errorCalls.length = 0

  return { db, poolConfigs, pools, loggerState, restore }
}

test('db config: env loader runs before default pool creation', () => {
  const poolConfigs = []

  function Pool(config) {
    poolConfigs.push(config)
    return {
      on() {}
    }
  }

  const fakeLogger = {
    info() {},
    error() {}
  }

  const fakeDotenv = {
    config() {
      process.env.DB_HOST = '127.0.0.1'
      process.env.DB_PORT = '5432'
      process.env.DB_USER = 'postgres'
      process.env.DB_PASSWORD = 'postgres'
      process.env.DB_NAME = 'taskdb'
      return { parsed: { DB_PASSWORD: 'postgres' } }
    }
  }

  const pgPath = require.resolve('pg')
  const dotenvPath = require.resolve('dotenv')
  const loggerPath = require.resolve('../src/utils/logger')
  const envPath = require.resolve('../src/config/env')
  const dbPath = require.resolve('../src/config/db')

  const savedNodeEnv = process.env.NODE_ENV
  const savedDbEnv = {
    DB_HOST: process.env.DB_HOST,
    DB_PORT: process.env.DB_PORT,
    DB_USER: process.env.DB_USER,
    DB_PASSWORD: process.env.DB_PASSWORD,
    DB_NAME: process.env.DB_NAME,
  }
  const savedPg = require.cache[pgPath]
  const savedDotenv = require.cache[dotenvPath]
  const savedLogger = require.cache[loggerPath]
  const savedEnv = require.cache[envPath]

  process.env.NODE_ENV = 'development'
  delete process.env.DB_HOST
  delete process.env.DB_PORT
  delete process.env.DB_USER
  delete process.env.DB_PASSWORD
  delete process.env.DB_NAME

  delete require.cache[envPath]
  delete require.cache[dbPath]

  require.cache[pgPath] = {
    id: pgPath,
    filename: pgPath,
    loaded: true,
    exports: { Pool }
  }
  require.cache[dotenvPath] = {
    id: dotenvPath,
    filename: dotenvPath,
    loaded: true,
    exports: fakeDotenv
  }
  require.cache[loggerPath] = {
    id: loggerPath,
    filename: loggerPath,
    loaded: true,
    exports: fakeLogger
  }

  try {
    require('../src/config/db')

    assert.deepEqual(poolConfigs[0], {
      host: '127.0.0.1',
      user: 'postgres',
      password: 'postgres',
      database: 'taskdb',
      port: 5432,
    })
  } finally {
    delete require.cache[envPath]
    delete require.cache[dbPath]

    if (savedPg) {
      require.cache[pgPath] = savedPg
    } else {
      delete require.cache[pgPath]
    }

    if (savedDotenv) {
      require.cache[dotenvPath] = savedDotenv
    } else {
      delete require.cache[dotenvPath]
    }

    if (savedLogger) {
      require.cache[loggerPath] = savedLogger
    } else {
      delete require.cache[loggerPath]
    }

    if (savedEnv) {
      require.cache[envPath] = savedEnv
    } else {
      delete require.cache[envPath]
    }

    process.env.NODE_ENV = savedNodeEnv

    for (const [key, value] of Object.entries(savedDbEnv)) {
      if (value === undefined) {
        delete process.env[key]
      } else {
        process.env[key] = value
      }
    }
  }
})

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

test('db config: explicit DB_SSL=disable overrides automatic Azure TLS and PGSSLMODE fallback', () => {
  const ctx = loadDbModule()
  const previousPgSslMode = process.env.PGSSLMODE

  process.env.PGSSLMODE = 'require'

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
      ssl: false,
    })
  } finally {
    if (previousPgSslMode === undefined) {
      delete process.env.PGSSLMODE
    } else {
      process.env.PGSSLMODE = previousPgSslMode
    }
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
      { mode: 'enabled', rejectUnauthorized: true }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'require',
        DB_SSL_REJECT_UNAUTHORIZED: 'off',
      }),
      { mode: 'enabled', rejectUnauthorized: false }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'require',
        DB_SSL_REJECT_UNAUTHORIZED: 'maybe',
      }),
      { mode: 'enabled', rejectUnauthorized: false }
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
      { mode: 'enabled', rejectUnauthorized: true }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        PGSSLMODE: 'verify-full',
      }),
      { mode: 'enabled', rejectUnauthorized: true }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_SSL: 'disable',
      }),
      { mode: 'disabled' }
    )

    assert.deepEqual(
      ctx.db.resolveSslConfig({
        DB_HOST: 'localhost',
      }),
      { mode: 'inherit' }
    )
  } finally {
    ctx.restore()
  }
})
