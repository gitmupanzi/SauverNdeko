const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const requireAdmin = require('../middlewares/requireAdmin');
const crudController = require('../controllers/crud.controller');
const adminUiSettingsController = require('../controllers/adminUiSettings.controller');

const router = express.Router();

router.use(verifyToken);
router.use(requireAdmin);

router.get('/models', crudController.listAvailableModels);
router.get('/models/:model', crudController.getAll);
router.get('/models/:model/:id', crudController.getOne);
router.post('/models/:model', crudController.create);
router.put('/models/:model/:id', crudController.update);
router.delete('/models/:model/:id', crudController.remove);
router.get('/admin-ui-settings', adminUiSettingsController.getAdminUiSettings);
router.put('/admin-ui-settings', adminUiSettingsController.updateAdminUiSettings);

module.exports = router;
