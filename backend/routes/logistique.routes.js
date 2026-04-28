const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const requireAdmin = require('../middlewares/requireAdmin');
const logistiqueController = require('../controllers/logistique.controller');

const router = express.Router();

router.use(verifyToken);
router.use(requireAdmin);

router.get('/dashboard', logistiqueController.getDashboardSummary);
router.get('/references', logistiqueController.listReferences);

router.get('/articles', logistiqueController.listArticles);
router.post('/articles', logistiqueController.createArticle);
router.put('/articles/:id', logistiqueController.updateArticle);
router.delete('/articles/:id', logistiqueController.removeArticle);

router.get('/commandes', logistiqueController.listCommandes);
router.post('/commandes', logistiqueController.createCommande);
router.put('/commandes/:id', logistiqueController.updateCommande);
router.get('/commandes/:id/details', logistiqueController.listCommandeDetails);
router.get('/mouvements', logistiqueController.listMouvements);
router.post('/commandes/:id/details', logistiqueController.createCommandeDetail);
router.put('/commandes/:id/details/:articleId', logistiqueController.updateCommandeDetail);
router.delete('/commandes/:id/details/:articleId', logistiqueController.removeCommandeDetail);

router.get('/stock/audit', logistiqueController.listAuditStock);
router.get('/stock/alertes', logistiqueController.listAlertesStock);
router.get('/stock/consommation', logistiqueController.listConsommation);
router.get('/stock/couverture', logistiqueController.listCouverture);

router.get('/commandes-sans-details', logistiqueController.listCommandesSansDetails);

router.get('/reglements/entries', logistiqueController.listReglementEntries);
router.get('/reglements', logistiqueController.listReglements);
router.post('/reglements', logistiqueController.createReglement);
router.put('/reglements/:id', logistiqueController.updateReglement);

module.exports = router;
