process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')
const proxyquire = require('proxyquire').noCallThru()

function createRes() {
  return {
    statusCodeSet: null,
    body: null,
    status(code) {
      this.statusCodeSet = code
      return this
    },
    json(payload) {
      this.body = payload
      return this
    }
  }
}

function makeController(serviceMock) {
  return proxyquire('../src/controllers/tasks.controller', {
    '../services/tasks.service': serviceMock
  })
}

test('create: returns 400 when title is whitespace-only', () => {
  const controller = makeController({ create() {} })
  const res = createRes()

  controller.create({ body: { title: '   ' } }, res)

  assert.equal(res.statusCodeSet, 400)
  assert.deepEqual(res.body, { error: 'title (string) is required' })
})

test('create: returns 400 when title is not a string', () => {
  const controller = makeController({ create() {} })
  const res = createRes()

  controller.create({ body: { title: 123 } }, res)

  assert.equal(res.statusCodeSet, 400)
  assert.deepEqual(res.body, { error: 'title (string) is required' })
})

test('create: returns 201 on success', () => {
  const controller = makeController({
    create(title) {
      return { id: 1, title, completed: false }
    }
  })
  const res = createRes()

  controller.create({ body: { title: '  hello ' } }, res)

  assert.equal(res.statusCodeSet, 201)
  assert.deepEqual(res.body, { id: 1, title: 'hello', completed: false })
})

test('update: returns 400 when title provided but empty', () => {
  const controller = makeController({ update() {} })
  const res = createRes()

  controller.update({ params: { id: '1' }, body: { title: '   ' } }, res)

  assert.equal(res.statusCodeSet, 400)
  assert.deepEqual(res.body, { error: 'title must be a non-empty string' })
})

test('update: returns 400 when completed is not boolean', () => {
  const controller = makeController({ update() {} })
  const res = createRes()

  controller.update({ params: { id: '1' }, body: { completed: 'yes' } }, res)

  assert.equal(res.statusCodeSet, 400)
  assert.deepEqual(res.body, { error: 'completed must be boolean' })
})

test('update: returns 200 when task updated', () => {
  let receivedId = null
  let receivedPatch = null

  const controller = makeController({
    update(id, patch) {
      receivedId = id
      receivedPatch = patch
      return { id, ...patch }
    }
  })
  const res = createRes()

  controller.update(
    { params: { id: '2' }, body: { title: '  ok  ', completed: true } },
    res
  )

  assert.equal(receivedId, 2)
  assert.deepEqual(receivedPatch, { title: 'ok', completed: true })
  assert.equal(res.statusCodeSet, null)
  assert.deepEqual(res.body, { id: 2, title: 'ok', completed: true })
})

test('update: returns 404 when task not found', () => {
  const controller = makeController({ update() { return null } })
  const res = createRes()

  controller.update({ params: { id: '999' }, body: { title: 'x' } }, res)

  assert.equal(res.statusCodeSet, 404)
  assert.deepEqual(res.body, { error: 'Task not found' })
})

test('update: returns 400 for invalid id', () => {
  const controller = makeController({ update() {} })

  assert.throws(
    () => controller.update({ params: { id: 'abc' }, body: {} }, createRes()),
    (err) => {
      assert.equal(err.message, 'id must be a positive integer')
      assert.equal(err.status, 400)
      return true
    }
  )
})

test('getAll: returns all tasks', () => {
  const tasks = [{ id: 1, title: 'a', completed: false }]
  const controller = makeController({ getAll: () => tasks })
  const res = createRes()

  controller.getAll({}, res)

  assert.deepEqual(res.body, tasks)
})

test('getById: returns task when found', () => {
  const task = { id: 1, title: 'a', completed: false }
  const controller = makeController({ getById: () => task })
  const res = createRes()

  controller.getById({ params: { id: '1' } }, res)

  assert.deepEqual(res.body, task)
})

test('getById: returns 404 when not found', () => {
  const controller = makeController({ getById: () => null })
  const res = createRes()

  controller.getById({ params: { id: '1' } }, res)

  assert.equal(res.statusCodeSet, 404)
  assert.deepEqual(res.body, { error: 'Task not found' })
})

test('remove: returns deleted task', () => {
  const task = { id: 1, title: 'a', completed: false }
  const controller = makeController({ remove: () => task })
  const res = createRes()

  controller.remove({ params: { id: '1' } }, res)

  assert.deepEqual(res.body, { deleted: task })
})

test('remove: returns 404 when not found', () => {
  const controller = makeController({ remove: () => null })
  const res = createRes()

  controller.remove({ params: { id: '1' } }, res)

  assert.equal(res.statusCodeSet, 404)
  assert.deepEqual(res.body, { error: 'Task not found' })
})
