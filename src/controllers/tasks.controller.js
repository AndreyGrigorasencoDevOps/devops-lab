const tasksService = require('../services/tasks.service')

function parseId(req) {
  const id = Number(req.params.id)
  if (!Number.isInteger(id) || id <= 0) {
    const err = new Error('id must be a positive integer')
    err.status = 400
    throw err
  }
  return id
}

exports.getAll = (req, res) => {
  res.json(tasksService.getAll())
}

exports.getById = (req, res) => {
  const id = parseId(req)
  const task = tasksService.getById(id)

  if (!task) return res.status(404).json({ error: 'Task not found' })
  res.json(task)
}

exports.create = (req, res) => {
  const { title } = req.body

  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    return res.status(400).json({ error: 'title (string) is required' })
  }

  const task = tasksService.create(title.trim())
  res.status(201).json(task)
}

exports.update = (req, res) => {
  const id = parseId(req)
  const { title, completed } = req.body

  if (title !== undefined) {
    if (typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({ error: 'title must be a non-empty string' })
    }
  }

  if (completed !== undefined && typeof completed !== 'boolean') {
    return res.status(400).json({ error: 'completed must be boolean' })
  }

  const updated = tasksService.update(id, {
    title: title !== undefined ? title.trim() : undefined,
    completed
  })

  if (!updated) return res.status(404).json({ error: 'Task not found' })
  res.json(updated)
}

exports.remove = (req, res) => {
  const id = parseId(req)
  const removed = tasksService.remove(id)

  if (!removed) return res.status(404).json({ error: 'Task not found' })
  res.json({ deleted: removed })
}