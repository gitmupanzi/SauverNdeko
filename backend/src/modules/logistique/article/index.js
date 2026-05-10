const express = require('express');
const prisma = require('../../../../config/db');
const logistiqueService = require('../../../../services/logistique.service');
const { createError, parseListQuery, parsePositiveInt } = require('../../shared/module-kit');

const repository = {
  delegate: prisma.t_Article,
  findById: (id) => prisma.t_Article.findUnique({ where: { ID_Article: id } }),
};

const viewRepository = {
  async list(query = {}) {
    return logistiqueService.listArticles(query);
  },
  async findById(id) {
    const result = await logistiqueService.listArticles({ article: id, take: 1 });
    return result.data?.[0] || null;
  },
};

const validation = {
  parseId: (value) => parsePositiveInt(value, 'article'),
  validateListQuery: (query) => parseListQuery(query),
  validateSearchQuery: (query) => {
    const parsed = parseListQuery(query);
    if (!parsed.q) {
      throw createError('Le parametre q est obligatoire pour la recherche.', 400, 'INVALID_QUERY', { field: 'q' });
    }
    return parsed;
  },
};

const service = {
  list: async (query) => viewRepository.list(query),
  search: async (query) => viewRepository.list(query),
  async getById(id) {
    const data = await viewRepository.findById(validation.parseId(id));
    if (!data) {
      throw createError('Article introuvable.', 404, 'NOT_FOUND');
    }
    return data;
  },
  create: async (payload, context) => logistiqueService.createArticle(payload, context?.req?.userId),
  update: async (id, payload, context) => logistiqueService.updateArticle(validation.parseId(id), payload, context?.req?.userId),
  remove: async (id, context) => {
    const hardDelete = String(context?.req?.query?.mode || '').toLowerCase() === 'hard';
    return logistiqueService.removeArticle(validation.parseId(id), { hardDelete });
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
      return sendSuccess(res, 200, 'Articles recuperes avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async search(req, res) {
    try {
      validation.validateSearchQuery(req.query);
      const result = await service.search(req.query);
      return sendSuccess(res, 200, 'Recherche des articles effectuee avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getById(req, res) {
    try {
      const data = await service.getById(req.params.id);
      return sendSuccess(res, 200, 'Article recupere avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async create(req, res) {
    try {
      const data = await service.create(req.body, { req });
      return sendSuccess(res, 201, 'Article cree avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async update(req, res) {
    try {
      const data = await service.update(req.params.id, req.body, { req });
      return sendSuccess(res, 200, 'Article mis a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async remove(req, res) {
    try {
      const data = await service.remove(req.params.id, { req });
      return sendSuccess(res, 200, 'Article desactive avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
};

const router = express.Router();
router.get('/search', controller.search);
router.get('/:id', controller.getById);
router.get('/', controller.list);
router.post('/', controller.create);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = { router, controller, service, repository, viewRepository, validation };
