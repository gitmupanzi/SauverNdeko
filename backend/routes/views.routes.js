const express = require('express');
const viewsController = require('../controllers/views.controller');

const router = express.Router();

router.get('/', viewsController.listAvailableViews);
router.get('/:schema/:view', viewsController.getView);

module.exports = router;
