const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const requireAdmin = require('../middlewares/requireAdmin');
const domainController = require('../controllers/domain.controller');

const router = express.Router();

router.use(verifyToken);
router.use(requireAdmin);

router.get('/utilisateurs', domainController.listUtilisateurs);
router.get('/utilisateurs/:id', domainController.getUtilisateur);
router.post('/utilisateurs', domainController.createUtilisateur);
router.put('/utilisateurs/:id', domainController.updateUtilisateur);
router.delete('/utilisateurs/:id', domainController.removeUtilisateur);

router.get('/entites', domainController.listEntites);
router.get('/entites/:id', domainController.getEntite);
router.post('/entites', domainController.createEntite);
router.put('/entites/:id', domainController.updateEntite);
router.delete('/entites/:id', domainController.removeEntite);

router.get('/licences', domainController.listLicences);
router.get('/licences/:id', domainController.getLicence);
router.post('/licences', domainController.createLicence);
router.put('/licences/:id', domainController.updateLicence);
router.delete('/licences/:id', domainController.removeLicence);

router.get('/articles', domainController.listArticles);
router.get('/articles/:id', domainController.getArticle);
router.post('/articles', domainController.createArticle);
router.put('/articles/:id', domainController.updateArticle);
router.delete('/articles/:id', domainController.removeArticle);

router.get('/recherches', domainController.listRecherches);
router.get('/recherches/:id', domainController.getRecherche);
router.post('/recherches', domainController.createRecherche);
router.delete('/recherches/:id', domainController.removeRecherche);

router.get('/commandes', domainController.listCommandes);
router.get('/commandes/:id', domainController.getCommande);
router.post('/commandes', domainController.createCommande);
router.put('/commandes/:id', domainController.updateCommande);
router.delete('/commandes/:id', domainController.removeCommande);

module.exports = router;
