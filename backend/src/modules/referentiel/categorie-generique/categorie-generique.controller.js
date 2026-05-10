const sendSuccess = (res, statusCode, message, data) =>
  res.status(statusCode).json({
    success: true,
    message,
    data,
    error: null,
  });

const normalizeError = (error) => {
  if (error && error.code === 'P2025') {
    return {
      statusCode: 404,
      message: 'Enregistrement introuvable.',
      error: {
        code: 'NOT_FOUND',
        details: error.meta || null,
      },
    };
  }

  if (error && error.code === 'P2002') {
    return {
      statusCode: 409,
      message: 'Conflit d unicite detecte.',
      error: {
        code: 'UNIQUE_CONSTRAINT',
        details: error.meta || null,
      },
    };
  }

  if (error && error.code === 'P2003') {
    return {
      statusCode: 409,
      message: 'Contrainte relationnelle detectee.',
      error: {
        code: 'RELATION_CONSTRAINT',
        details: error.meta || null,
      },
    };
  }

  return {
    statusCode: error.statusCode || 500,
    message: error.message || 'Une erreur est survenue.',
    error: {
      code: error.code || 'INTERNAL_ERROR',
      details: error.details || null,
    },
  };
};

const sendError = (res, error) => {
  const normalized = normalizeError(error);

  return res.status(normalized.statusCode).json({
    success: false,
    message: normalized.message,
    data: null,
    error: normalized.error,
  });
};

const createCategorieGeneriqueController = (service) => ({
  listCategoriesGeneriques: async (req, res) => {
    try {
      const data = await service.listCategoriesGeneriques(req.query);
      return sendSuccess(res, 200, 'Categories generiques recuperees avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  searchCategoriesGeneriques: async (req, res) => {
    try {
      const data = await service.searchCategoriesGeneriques(req.query);
      return sendSuccess(res, 200, 'Recherche des categories generiques effectuee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  getCategorieGeneriqueById: async (req, res) => {
    try {
      const data = await service.getCategorieGeneriqueById(req.params.id);
      return sendSuccess(res, 200, 'Categorie generique recuperee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  createCategorieGenerique: async (req, res) => {
    try {
      const data = await service.createCategorieGenerique(req.body);
      return sendSuccess(res, 201, 'Categorie generique creee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  updateCategorieGenerique: async (req, res) => {
    try {
      const data = await service.updateCategorieGenerique(req.params.id, req.body);
      return sendSuccess(res, 200, 'Categorie generique mise a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  deleteCategorieGenerique: async (req, res) => {
    try {
      const data = await service.deleteCategorieGenerique(req.params.id);
      return sendSuccess(res, 200, 'Categorie generique desactivee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
});

module.exports = {
  createCategorieGeneriqueController,
};
