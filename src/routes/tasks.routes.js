const express = require('express')
const router = express.Router()

const tasksController = require('../controllers/tasks.controller')

router.get('/', tasksController.getAll)
router.get('/:id', tasksController.getById)
router.post('/', tasksController.create)
router.patch('/:id', tasksController.update)   // частичное обновление
router.delete('/:id', tasksController.remove)

module.exports = router