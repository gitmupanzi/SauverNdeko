const prisma = require('../../../../config/db');
const { createGeneriqueController } = require('./generique.controller');
const { GeneriqueRepository } = require('./generique.repository');
const { createGeneriqueRoutes } = require('./generique.routes');
const { GeneriqueService } = require('./generique.service');

const repository = new GeneriqueRepository(prisma);
const service = new GeneriqueService(repository);
const controller = createGeneriqueController(service);
const router = createGeneriqueRoutes(controller);

module.exports = {
  router,
  controller,
  service,
  repository,
};
