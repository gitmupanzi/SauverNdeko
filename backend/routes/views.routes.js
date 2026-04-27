const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const requireAdmin = require('../middlewares/requireAdmin');
const viewsController = require('../controllers/views.controller');

const router = express.Router();

router.use(verifyToken);
router.use(requireAdmin);

router.get('/', viewsController.listAvailableViews);
router.get('/:schema/:view', viewsController.getView);

module.exports = router;
