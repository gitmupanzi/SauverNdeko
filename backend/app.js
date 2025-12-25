//backend/app.js
const express = require('express');
const app = express();
const routes = require('./routes/index.routes'); 
const viewsRoutes = require('./routes/views.routes');
const authRoutes = require('./routes/auth.routes'); 
const errorHandler = require('./middlewares/errorHandler');


app.use(express.json()); // Middleware pour gérer les requêtes JSON
app.use('/api', routes); // Routes générales
app.use('/api', viewsRoutes); // Routes pour les vues (ex : V_Apprenant, VS_Exemple, etc.)
app.use('/SauverNdeko', authRoutes); //pour le token
app.use(errorHandler);// Gestion des erreurs globales

module.exports = app;

