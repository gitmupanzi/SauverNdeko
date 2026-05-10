const express = require('express');

const createGeneriqueRoutes = (controller) => {
  const router = express.Router();

  router.get('/search', controller.searchGeneriques);
  router.get('/categorie/:categorieId', controller.listGeneriquesByCategorie);
  router.get('/:id', controller.getGeneriqueById);
  router.get('/', controller.listGeneriques);
  router.post('/', controller.createGenerique);
  router.put('/:id', controller.updateGenerique);
  router.delete('/:id', controller.deleteGenerique);

  return router;
};

module.exports = {
  createGeneriqueRoutes,
};
