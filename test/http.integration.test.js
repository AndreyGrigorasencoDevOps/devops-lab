process.env.NODE_ENV = 'test'
process.env.LOG_LEVEL = 'fatal'

const test = require("node:test")
const assert = require("node:assert/strict")
const request = require("supertest")

const app = require("../src/app")

function assertTaskShape(task) {
  assert.equal(typeof task.id, "number")
  assert.equal(typeof task.title, "string")
  assert.equal(typeof task.completed, "boolean")
  assert.equal(typeof task.createdAt, "string")
  // updatedAt can be string or null
  assert.ok(typeof task.updatedAt === "string" || task.updatedAt === null)
}

test("GET /health returns liveness", async () => {
  const res = await request(app).get("/health").expect(200)
  assert.deepEqual(Object.keys(res.body).sort((a, b) => a.localeCompare(b)), ["service", "status"])
  assert.equal(res.body.status, "ok")
  assert.equal(typeof res.body.service, "string")
})

test("GET /info returns service metadata", async () => {
  const res = await request(app).get("/info").expect(200)

  assert.deepEqual(Object.keys(res.body).sort((a, b) => a.localeCompare(b)), ["node", "port", "service", "uptimeSec"])
  assert.equal(typeof res.body.service, "string")
  assert.equal(typeof res.body.port, "number")
  assert.equal(typeof res.body.node, "string")
  assert.equal(typeof res.body.uptimeSec, "number")
})

test("Tasks CRUD: list -> create -> get -> patch -> delete", async () => {
  // 1) list tasks (in-memory store; should start empty in a fresh process)
  const list1 = await request(app).get("/tasks").expect(200)
  assert.ok(Array.isArray(list1.body))

  // 2) create task
  const created = await request(app)
    .post("/tasks")
    .send({ title: "Buy milk" })
    .set("Content-Type", "application/json")
    .expect(201)

  assertTaskShape(created.body)
  assert.equal(created.body.title, "Buy milk")
  assert.equal(created.body.completed, false)

  const id = created.body.id

  // 3) get by id
  const got = await request(app).get(`/tasks/${id}`).expect(200)
  assertTaskShape(got.body)
  assert.equal(got.body.id, id)

  // 4) patch update: completed true
  const patched = await request(app)
    .patch(`/tasks/${id}`)
    .send({ completed: true })
    .set("Content-Type", "application/json")
    .expect(200)

  assertTaskShape(patched.body)
  assert.equal(patched.body.completed, true)
  // updatedAt should become a string after update (if your impl sets it)
  assert.ok(typeof patched.body.updatedAt === "string" || patched.body.updatedAt === null)

  // 5) delete
  const del = await request(app).delete(`/tasks/${id}`).expect(200)
  assert.deepEqual(Object.keys(del.body), ["deleted"])
  assertTaskShape(del.body.deleted)
  assert.equal(del.body.deleted.id, id)

  // 6) get after delete => 404
  const after = await request(app).get(`/tasks/${id}`).expect(404)
  assert.deepEqual(after.body, { error: "Task not found" })
})

test("POST /tasks validates title", async () => {
  // missing title
  const res1 = await request(app)
    .post("/tasks")
    .send({})
    .set("Content-Type", "application/json")
    .expect(400)
  assert.deepEqual(res1.body, { error: "title (string) is required" })

  // empty title
  const res2 = await request(app)
    .post("/tasks")
    .send({ title: "   " })
    .set("Content-Type", "application/json")
    .expect(400)
  assert.deepEqual(res2.body, { error: "title (string) is required" })
})

test("PATCH /tasks/:id validates fields", async () => {
  // create a task first
  const created = await request(app)
    .post("/tasks")
    .send({ title: "Initial" })
    .set("Content-Type", "application/json")
    .expect(201)

  const id = created.body.id

  // invalid title
  const badTitle = await request(app)
    .patch(`/tasks/${id}`)
    .send({ title: "" })
    .set("Content-Type", "application/json")
    .expect(400)
  assert.deepEqual(badTitle.body, { error: "title must be a non-empty string" })

  // invalid completed type
  const badCompleted = await request(app)
    .patch(`/tasks/${id}`)
    .send({ completed: "yes" })
    .set("Content-Type", "application/json")
    .expect(400)
  assert.deepEqual(badCompleted.body, { error: "completed must be boolean" })
})

test("GET /tasks/:id returns 404 for missing task", async () => {
  const res = await request(app).get("/tasks/999999").expect(404)
  assert.deepEqual(res.body, { error: "Task not found" })
})

test("Invalid :id returns 400", async () => {
  const res1 = await request(app).get("/tasks/abc").expect(400)
  assert.equal(typeof res1.body.error, "string")

  const res2 = await request(app).get("/tasks/0").expect(400)
  assert.equal(typeof res2.body.error, "string")

  const res3 = await request(app).get("/tasks/-1").expect(400)
  assert.equal(typeof res3.body.error, "string")
})