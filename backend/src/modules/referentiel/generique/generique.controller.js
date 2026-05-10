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

const createGeneriqueController = (service) => ({
  listGeneriques: async (req, res) => {
    try {
      const data = await service.listGeneriques(req.query);
      return sendSuccess(res, 200, 'Generiques recuperes avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  searchGeneriques: async (req, res) => {
    try {
      const data = await service.searchGeneriques(req.query);
      return sendSuccess(res, 200, 'Recherche des generiques effectuee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  listGeneriquesByCategorie: async (req, res) => {
    try {
      const data = await service.listGeneriquesByCategorie(req.params.categorieId, req.query);
      return sendSuccess(res, 200, 'Generiques recuperes par categorie avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  getGeneriqueById: async (req, res) => {
    try {
      const data = await service.getGeneriqueById(req.params.id);
      return sendSuccess(res, 200, 'Generique recupere avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  createGenerique: async (req, res) => {
    try {
      const data = await service.createGenerique(req.body);
      return sendSuccess(res, 201, 'Generique cree avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  updateGenerique: async (req, res) => {
    try {
      const data = await service.updateGenerique(req.params.id, req.body);
      return sendSuccess(res, 200, 'Generique mis a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },

  deleteGenerique: async (req, res) => {
    try {
      const data = await service.deleteGenerique(req.params.id);
      return sendSuccess(res, 200, 'Generique desactive avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
});

module.exports = {
  createGeneriqueController,
};
