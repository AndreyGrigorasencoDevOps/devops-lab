process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require('node:test')
const assert = require('node:assert/strict')

function freshService() {
  delete require.cache[require.resolve('../src/services/tasks.service')]
  return require('../src/services/tasks.service')
}

test('create: returns task with correct shape', () => {
  const svc = freshService()

  const task = svc.create('hello')

  assert.equal(task.title, 'hello')
  assert.equal(task.completed, false)
  assert.equal(typeof task.id, 'number')
  assert.equal(typeof task.createdAt, 'string')
  assert.equal(task.updatedAt, null)
})

test('getAll: returns all created tasks', () => {
  const svc = freshService()

  svc.create('a')
  svc.create('b')

  const all = svc.getAll()

  assert.equal(all.length, 2)
})

test('getById: returns task when found', () => {
  const svc = freshService()

  const created = svc.create('find me')

  assert.deepEqual(svc.getById(created.id), created)
})

test('getById: returns undefined when not found', () => {
  const svc = freshService()

  assert.equal(svc.getById(999), undefined)
})

test('update: updates title and completed', () => {
  const svc = freshService()

  const created = svc.create('old')
  const updated = svc.update(created.id, { title: 'new', completed: true })

  assert.equal(updated.title, 'new')
  assert.equal(updated.completed, true)
  assert.ok(updated.updatedAt)
})

test('update: updates only updatedAt when patch has no fields', () => {
  const svc = freshService()

  const created = svc.create('task')
  const updated = svc.update(created.id, {})

  assert.equal(updated.title, 'task')
  assert.equal(updated.completed, false)
  assert.ok(updated.updatedAt)
})

test('update: returns null when task not found', () => {
  const svc = freshService()

  assert.equal(svc.update(999, { title: 'x' }), null)
})

test('remove: removes and returns task', () => {
  const svc = freshService()

  const created = svc.create('remove me')
  const removed = svc.remove(created.id)

  assert.equal(removed.id, created.id)
  assert.equal(svc.getAll().length, 0)
})

test('remove: returns null when task not found', () => {
  const svc = freshService()

  assert.equal(svc.remove(999), null)
})
