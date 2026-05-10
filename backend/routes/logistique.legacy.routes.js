const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const requireAdmin = require('../middlewares/requireAdmin');
const logistiqueController = require('../controllers/logistique.controller');

const router = express.Router();

router.use(verifyToken);
router.use(requireAdmin);

// Endpoints legacy conserves tant que le frontend ou d'autres clients
// n'ont pas ete migres vers les nouveaux modules REST officiels.
router.get('/references', logistiqueController.listReferences);

router.get('/commandes/:id/details', logistiqueController.listCommandeDetails);
router.post('/commandes/:id/details', logistiqueController.createCommandeDetail);
router.put('/commandes/:id/details/:articleId', logistiqueController.updateCommandeDetail);
router.delete('/commandes/:id/details/:articleId', logistiqueController.removeCommandeDetail);

router.get('/stock/audit', logistiqueController.listAuditStock);
router.get('/stock/alertes', logistiqueController.listAlertesStock);
router.get('/stock/consommation', logistiqueController.listConsommation);
router.get('/stock/couverture', logistiqueController.listCouverture);

router.get('/commandes-sans-details', logistiqueController.listCommandesSansDetails);
router.get('/reglements/entries', logistiqueController.listReglementEntries);

module.exports = router;
