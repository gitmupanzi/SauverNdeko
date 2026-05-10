const express = require('express');
const logistiqueService = require('../../../../services/logistique.service');
const { createError, parseListQuery, parsePositiveInt } = require('../../shared/module-kit');

const viewRepository = {
  async list(query = {}) {
    return logistiqueService.listMouvements(query);
  },
  async findById(id) {
    const result = await logistiqueService.listMouvements({ mouvement: id, take: 1 });
    return result.data?.[0] || null;
  },
};

const validation = {
  parseId: (value) => parsePositiveInt(value, 'mouvement'),
  validateSearchQuery: (query) => {
    const parsed = parseListQuery(query);
    if (!parsed.q) {
      throw createError('Le parametre q est obligatoire pour la recherche.', 400, 'INVALID_QUERY', { field: 'q' });
    }
    return parsed;
  },
};

const service = {
  list: (query) => viewRepository.list(query),
  search: (query) => viewRepository.list(query),
  async getById(id) {
    const data = await viewRepository.findById(validation.parseId(id));
    if (!data) {
      throw createError('Mouvement introuvable.', 404, 'NOT_FOUND');
    }
    return data;
  },
};

const sendSuccess = (res, statusCode, message, data) =>
  res.status(statusCode).json({ success: true, message, data, error: null });
const sendError = (res, error) =>
  res.status(error.statusCode || 500).json({
    success: false,
    message: error.message || 'Une erreur est survenue',
    data: null,
    error: { code: error.code || 'INTERNAL_ERROR', details: error.details || null },
  });

const controller = {
  async list(req, res) {
    try {
      const result = await service.list(req.query);
      return sendSuccess(res, 200, 'Mouvements recuperes avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async search(req, res) {
    try {
      validation.validateSearchQuery(req.query);
      const result = await service.search(req.query);
      return sendSuccess(res, 200, 'Recherche des mouvements effectuee avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getById(req, res) {
    try {
      const data = await service.getById(req.params.id);
      return sendSuccess(res, 200, 'Mouvement recupere avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
};

const router = express.Router();
router.get('/search', controller.search);
router.get('/:id', controller.getById);
router.get('/', controller.list);

module.exports = { router, controller, service, viewRepository, validation, writeEnabled: false };
