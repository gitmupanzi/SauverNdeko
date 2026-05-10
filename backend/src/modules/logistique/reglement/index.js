const express = require('express');
const prisma = require('../../../../config/db');
const logistiqueService = require('../../../../services/logistique.service');
const { createError, parseListQuery, parsePositiveInt, quoteIdentifier, quoteQualifiedName } = require('../../shared/module-kit');

const repository = {
  delegate: prisma.t_Reglements,
  findById: (id) => prisma.t_Reglements.findUnique({ where: { ID_Reglement: id } }),
  delete: (id) => prisma.t_Reglements.delete({ where: { ID_Reglement: id } }),
};

const viewRepository = {
  async list(query = {}) {
    const parsed = parseListQuery(query);
    const clauses = [];

    if (parsed.q) {
      const q = String(parsed.q).replace(/'/g, "''");
      clauses.push(`("CodeFacture" ILIKE '%${q}%' OR "EtatReglement" ILIKE '%${q}%')`);
    }

    const sql = `SELECT * FROM ${quoteQualifiedName('logistique', 'V_SuiviReglements')}${clauses.length ? ` WHERE ${clauses.join(' AND ')}` : ''} ORDER BY ${quoteIdentifier(
      'ID_Commande'
    )} DESC LIMIT ${parsed.take} OFFSET ${parsed.skip}`;
    return prisma.$queryRawUnsafe(sql);
  },
};

const validation = {
  parseId: (value) => parsePositiveInt(value, 'reglement'),
};

const service = {
  list: (query) => viewRepository.list(query),
  search: (query) => viewRepository.list(query),
  async getById(id) {
    const data = await repository.findById(validation.parseId(id));
    if (!data) {
      throw createError('Reglement introuvable.', 404, 'NOT_FOUND');
    }
    return data;
  },
  create: (payload) => logistiqueService.createReglement(payload),
  update: (id, payload) => logistiqueService.updateReglement(validation.parseId(id), payload),
  async remove(id) {
    const reglementId = validation.parseId(id);
    const existing = await repository.findById(reglementId);
    if (!existing) {
      throw createError('Reglement introuvable.', 404, 'NOT_FOUND');
    }
    return repository.delete(reglementId);
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
      const data = await service.list(req.query);
      return sendSuccess(res, 200, 'Reglements recuperes avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async search(req, res) {
    try {
      const data = await service.search(req.query);
      return sendSuccess(res, 200, 'Recherche des reglements effectuee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getById(req, res) {
    try {
      const data = await service.getById(req.params.id);
      return sendSuccess(res, 200, 'Reglement recupere avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async create(req, res) {
    try {
      const data = await service.create(req.body);
      return sendSuccess(res, 201, 'Reglement cree avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async update(req, res) {
    try {
      const data = await service.update(req.params.id, req.body);
      return sendSuccess(res, 200, 'Reglement mis a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async remove(req, res) {
    try {
      const data = await service.remove(req.params.id);
      return sendSuccess(res, 200, 'Reglement supprime avec succes.', data);
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
