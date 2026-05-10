const express = require('express');
const prisma = require('../../../../config/db');
const logistiqueService = require('../../../../services/logistique.service');
const { createError, parseListQuery, parsePositiveInt } = require('../../shared/module-kit');

const repository = {
  delegate: prisma.t_Commande,
  findById: (id) => prisma.t_Commande.findUnique({ where: { ID_Commande: id } }),
};

const viewRepository = {
  async list(query = {}) {
    return logistiqueService.listCommandes(query);
  },
  async findById(id) {
    const result = await logistiqueService.listCommandes({ commande: id, take: 1 });
    return result.data?.[0] || null;
  },
};

const validation = {
  parseId: (value) => parsePositiveInt(value, 'commande'),
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
  list: (query) => viewRepository.list(query),
  search: (query) => viewRepository.list(query),
  async getById(id) {
    const data = await viewRepository.findById(validation.parseId(id));
    if (!data) {
      throw createError('Commande introuvable.', 404, 'NOT_FOUND');
    }
    return data;
  },
  create: (payload, context) => logistiqueService.createCommande(payload, context?.req?.userId),
  update: (id, payload, context) => logistiqueService.updateCommande(validation.parseId(id), payload, context?.req?.userId),
  remove: (id) => logistiqueService.removeCommande(validation.parseId(id)),
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
      return sendSuccess(res, 200, 'Commandes recuperees avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async search(req, res) {
    try {
      validation.validateSearchQuery(req.query);
      const result = await service.search(req.query);
      return sendSuccess(res, 200, 'Recherche des commandes effectuee avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getById(req, res) {
    try {
      const data = await service.getById(req.params.id);
      return sendSuccess(res, 200, 'Commande recuperee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async create(req, res) {
    try {
      const data = await service.create(req.body, { req });
      return sendSuccess(res, 201, 'Commande creee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async update(req, res) {
    try {
      const data = await service.update(req.params.id, req.body, { req });
      return sendSuccess(res, 200, 'Commande mise a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async remove(req, res) {
    try {
      const data = await service.remove(req.params.id);
      return sendSuccess(res, 200, 'Commande supprimee avec succes.', data || null);
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
