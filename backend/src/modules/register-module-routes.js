const referentielModules = require('./referentiel');
const systemeModules = require('./systeme');
const logistiqueModules = require('./logistique');
const geolocalisationModules = require('./geolocalisation');

const registerModuleRoutes = (app) => {
  app.use('/api/referentiel/categories-generiques', referentielModules.categorieGenerique.router);
  app.use('/api/referentiel/generiques', referentielModules.generique.router);

  app.use('/api/systeme/utilisateurs', systemeModules.utilisateur.router);
  app.use('/api/systeme/entites', systemeModules.entite.router);
  app.use('/api/systeme/entite-localisations', systemeModules.entiteLocalisation.router);
  app.use('/api/systeme/licences', systemeModules.licence.router);
  app.use('/api/systeme/logins', systemeModules.login.router);
  app.use('/api/systeme/audit-logs', systemeModules.auditLog.router);
  app.use('/api/systeme/fk-correspondances', systemeModules.fkCorrespondance.router);
  app.use('/api/systeme/admin-ui-settings', systemeModules.adminUiSetting.router);

  app.use('/api/logistique/articles', logistiqueModules.article.router);
  app.use('/api/logistique/commandes', logistiqueModules.commande.router);
  app.use('/api/logistique/commande-details', logistiqueModules.commandeDetail.router);
  app.use('/api/logistique/reglements', logistiqueModules.reglement.router);
  app.use('/api/logistique/mouvements', logistiqueModules.mouvement.router);
  app.use('/api/logistique/stock', logistiqueModules.stock.router);
  app.use('/api/logistique/dashboard', logistiqueModules.dashboard.router);

  app.use('/api/geolocalisation/niveau-0', geolocalisationModules.niveau0.router);
  app.use('/api/geolocalisation/niveau-1-old', geolocalisationModules.niveau1Old.router);
  app.use('/api/geolocalisation/niveau-1', geolocalisationModules.niveau1.router);
  app.use('/api/geolocalisation/niveau-2', geolocalisationModules.niveau2.router);
  app.use('/api/geolocalisation/niveau-3', geolocalisationModules.niveau3.router);
  app.use('/api/geolocalisation/niveau-4', geolocalisationModules.niveau4.router);
  app.use('/api/geolocalisation/niveau-5', geolocalisationModules.niveau5.router);
  app.use('/api/geolocalisation/hierarchie', geolocalisationModules.hierarchie.router);
};

module.exports = registerModuleRoutes;
