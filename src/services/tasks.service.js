let tasks = []
let idCounter = 1

exports.getAll = () => tasks

exports.getById = (id) => tasks.find(t => t.id === id)

exports.create = (title) => {
  const newTask = {
    id: idCounter++,
    title,
    completed: false,
    createdAt: new Date().toISOString(),
    updatedAt: null
  }

  tasks.push(newTask)
  return newTask
}

exports.update = (id, patch) => {
  const task = tasks.find(t => t.id === id)
  if (!task) return null

  if (patch.title !== undefined) task.title = patch.title
  if (patch.completed !== undefined) task.completed = patch.completed

  task.updatedAt = new Date().toISOString()
  return task
}

exports.remove = (id) => {
  const idx = tasks.findIndex(t => t.id === id)
  if (idx === -1) return null
  return tasks.splice(idx, 1)[0]
}