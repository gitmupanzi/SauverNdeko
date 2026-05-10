const express = require('express');

const createCategorieGeneriqueRoutes = (controller) => {
  const router = express.Router();

  router.get('/search', controller.searchCategoriesGeneriques);
  router.get('/:id', controller.getCategorieGeneriqueById);
  router.get('/', controller.listCategoriesGeneriques);
  router.post('/', controller.createCategorieGenerique);
  router.put('/:id', controller.updateCategorieGenerique);
  router.delete('/:id', controller.deleteCategorieGenerique);

  return router;
};

module.exports = {
  createCategorieGeneriqueRoutes,
};
