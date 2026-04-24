const path = require('path');

require('dotenv').config({
  path: path.join(__dirname, '.env'),
});

const app = require('./app');
const prisma = require('./config/db');

const port = process.env.PORT || 5000;

async function startServer() {
  try {
    await prisma.$connect();

    const dbInfo = await prisma.$queryRawUnsafe(
      'SELECT current_database() AS db, inet_server_addr()::text AS host, inet_server_port() AS port'
    );

    const currentDb = dbInfo[0] || {};

    app.listen(port, () => {
      console.log(`Serveur Express demarre sur le port ${port}`);
      console.log(
        `Connexion base OK: ${currentDb.db || 'unknown'} @ ${currentDb.host || 'localhost'}:${currentDb.port || 'unknown'}`
      );
    });
  } catch (error) {
    console.error('Echec de connexion a la base de donnees.');
    console.error(error && error.stack ? error.stack : error);
    process.exit(1);
  }
}

async function shutdown(signal) {
  try {
    await prisma.$disconnect();
  } finally {
    process.exit(0);
  }
}

process.on('SIGINT', () => {
  shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});

startServer();
