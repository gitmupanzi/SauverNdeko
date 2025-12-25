// backend/server.js
const express = require('express');
const app = require('./app');
const port = process.env.PORT || 5000; 

// Lancer le serveur
app.listen(port, () => {
  console.log(`Serveur Express démarré sur le port ${port}`);
});