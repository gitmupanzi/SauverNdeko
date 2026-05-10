const express = require('express');
const prisma = require('../../../../config/db');
const logistiqueService = require('../../../../services/logistique.service');
const { createError, parseListQuery, parsePositiveInt, quoteIdentifier, quoteQualifiedName } = require('../../shared/module-kit');

const repository = {
  delegate: prisma.t_CommandeDetail,
  findByIds: (commandeId, articleId) =>
    prisma.t_CommandeDetail.findUnique({
      where: {
        ID_ArticleFk_ID_CmdFk: {
          ID_ArticleFk: articleId,
          ID_CmdFk: commandeId,
        },
      },
    }),
};

const viewRepository = {
  async list(query = {}) {
    const parsed = parseListQuery(query);
    const clauses = [];

    if (parsed.q) {
      const q = String(parsed.q).replace(/'/g, "''");
      clauses.push(
        `("CodeCmd" ILIKE '%${q}%' OR "CodeFacture" ILIKE '%${q}%' OR "CodeArticleInterne" ILIKE '%${q}%' OR "NomArticle" ILIKE '%${q}%')`
      );
    }

    if (query.commande) {
      clauses.push(`"ID_CmdFk" = ${parsePositiveInt(query.commande, 'commande')}`);
    }

    if (query.article) {
      clauses.push(`"ID_ArticleFk" = ${parsePositiveInt(query.article, 'article')}`);
    }

    const whereClause = clauses.length ? ` WHERE ${clauses.join(' AND ')}` : '';
    const sql = `SELECT * FROM ${quoteQualifiedName('logistique', 'V_CommandeDetail')}${whereClause} ORDER BY ${quoteIdentifier(
      'ID_CmdFk'
    )} DESC LIMIT ${parsed.take} OFFSET ${parsed.skip}`;
    return prisma.$queryRawUnsafe(sql);
  },
  async findByIds(commandeId, articleId) {
    const sql = `SELECT * FROM ${quoteQualifiedName('logistique', 'V_CommandeDetail')} WHERE "ID_CmdFk" = ${commandeId} AND "ID_ArticleFk" = ${articleId} LIMIT 1`;
    const rows = await prisma.$queryRawUnsafe(sql);
    return rows[0] || null;
  },
};

const validation = {
  parseIds: (commandeId, articleId) => ({
    commandeId: parsePositiveInt(commandeId, 'commandeId'),
    articleId: parsePositiveInt(articleId, 'articleId'),
  }),
  parseBodyIds: (body) => ({
    commandeId: parsePositiveInt(body.ID_CmdFk, 'ID_CmdFk'),
    articleId: parsePositiveInt(body.ID_ArticleFk, 'ID_ArticleFk'),
  }),
};

const service = {
  list: (query) => viewRepository.list(query),
  search: (query) => viewRepository.list(query),
  async getByIds(commandeId, articleId) {
    const ids = validation.parseIds(commandeId, articleId);
    const data = await viewRepository.findByIds(ids.commandeId, ids.articleId);
    if (!data) {
      throw createError('Ligne de commande introuvable.', 404, 'NOT_FOUND');
    }
    return data;
  },
  async create(payload) {
    const ids = validation.parseBodyIds(payload);
    return logistiqueService.createCommandeDetail(ids.commandeId, payload);
  },
  async update(commandeId, articleId, payload) {
    const ids = validation.parseIds(commandeId, articleId);
    return logistiqueService.updateCommandeDetail(ids.commandeId, ids.articleId, payload);
  },
  async remove(commandeId, articleId) {
    const ids = validation.parseIds(commandeId, articleId);
    return logistiqueService.removeCommandeDetail(ids.commandeId, ids.articleId);
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
      return sendSuccess(res, 200, 'Lignes de commande recuperees avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async search(req, res) {
    try {
      const data = await service.search(req.query);
      return sendSuccess(res, 200, 'Recherche des lignes de commande effectuee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getByIds(req, res) {
    try {
      const data = await service.getByIds(req.params.commandeId, req.params.articleId);
      return sendSuccess(res, 200, 'Ligne de commande recuperee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async create(req, res) {
    try {
      const data = await service.create(req.body);
      return sendSuccess(res, 201, 'Ligne de commande creee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async update(req, res) {
    try {
      const data = await service.update(req.params.commandeId, req.params.articleId, req.body);
      return sendSuccess(res, 200, 'Ligne de commande mise a jour avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async remove(req, res) {
    try {
      await service.remove(req.params.commandeId, req.params.articleId);
      return sendSuccess(res, 200, 'Ligne de commande supprimee avec succes.', null);
    } catch (error) {
      return sendError(res, error);
    }
  },
};

const router = express.Router();
router.get('/search', controller.search);
router.get('/:commandeId/:articleId', controller.getByIds);
router.get('/', controller.list);
router.post('/', controller.create);
router.put('/:commandeId/:articleId', controller.update);
router.delete('/:commandeId/:articleId', controller.remove);

module.exports = { router, controller, service, repository, viewRepository, validation };
