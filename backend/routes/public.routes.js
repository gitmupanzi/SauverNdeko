const express = require('express');
const publicController = require('../controllers/public.controller');

const router = express.Router();

router.get('/stats', publicController.getPublicStats);
router.get('/articles', publicController.listPublicArticles);
router.get('/pharmacies', publicController.listPublicPharmacies);
router.get('/experts', publicController.listPublicExperts);
router.get('/maladies', publicController.listPublicMaladies);
router.get('/chat/context', publicController.getPublicChatContext);

module.exports = router;
