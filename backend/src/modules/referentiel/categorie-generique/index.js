const prisma = require('../../../../config/db');
const { createCategorieGeneriqueController } = require('./categorie-generique.controller');
const { CategorieGeneriqueRepository } = require('./categorie-generique.repository');
const { createCategorieGeneriqueRoutes } = require('./categorie-generique.routes');
const { CategorieGeneriqueService } = require('./categorie-generique.service');

const repository = new CategorieGeneriqueRepository(prisma);
const service = new CategorieGeneriqueService(repository);
const controller = createCategorieGeneriqueController(service);
const router = createCategorieGeneriqueRoutes(controller);

module.exports = {
  router,
  controller,
  service,
  repository,
};
