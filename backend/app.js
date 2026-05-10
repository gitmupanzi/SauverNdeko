const express = require('express');
const cors = require('cors');
const routes = require('./routes/index.routes');
const domainRoutes = require('./routes/domain.routes');
const viewsRoutes = require('./routes/views.routes');
const authRoutes = require('./routes/auth.routes');
const publicRoutes = require('./routes/public.routes');
const discussionRoutes = require('./routes/discussion.routes');
const logistiqueRoutes = require('./routes/logistique.routes');
const referentielModules = require('./src/modules/referentiel');
const systemeModules = require('./src/modules/systeme');
const logistiqueModules = require('./src/modules/logistique');
const geolocalisationModules = require('./src/modules/geolocalisation');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'SauverNdeko backend is running.',
  });
});

app.use('/api/public', publicRoutes);
app.use('/api/discussions', discussionRoutes);
app.use('/api/logistique', logistiqueRoutes);
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
app.use('/api/v2/logistique/articles', logistiqueModules.article.router);
app.use('/api/v2/logistique/commandes', logistiqueModules.commande.router);
app.use('/api/v2/logistique/commande-details', logistiqueModules.commandeDetail.router);
app.use('/api/v2/logistique/reglements', logistiqueModules.reglement.router);
app.use('/api/v2/logistique/mouvements', logistiqueModules.mouvement.router);
app.use('/api/v2/logistique/stock', logistiqueModules.stock.router);
app.use('/api/v2/logistique/dashboard', logistiqueModules.dashboard.router);
app.use('/api/geolocalisation/niveau-0', geolocalisationModules.niveau0.router);
app.use('/api/geolocalisation/niveau-1-old', geolocalisationModules.niveau1Old.router);
app.use('/api/geolocalisation/niveau-1', geolocalisationModules.niveau1.router);
app.use('/api/geolocalisation/niveau-2', geolocalisationModules.niveau2.router);
app.use('/api/geolocalisation/niveau-3', geolocalisationModules.niveau3.router);
app.use('/api/geolocalisation/niveau-4', geolocalisationModules.niveau4.router);
app.use('/api/geolocalisation/niveau-5', geolocalisationModules.niveau5.router);
app.use('/api/geolocalisation/hierarchie', geolocalisationModules.hierarchie.router);
app.use('/api', domainRoutes);
app.use('/api', routes);
app.use('/api/views', viewsRoutes);
app.use('/SauverNdeko', authRoutes);
app.use(errorHandler);

module.exports = app;
