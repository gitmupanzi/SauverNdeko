const express = require('express');
const prisma = require('../../../../config/db');
const { createError, parsePositiveInt } = require('../../shared/module-kit');

const sendSuccess = (res, statusCode, message, data) =>
  res.status(statusCode).json({
    success: true,
    message,
    data,
    error: null,
  });

const sendError = (res, error) =>
  res.status(error.statusCode || 500).json({
    success: false,
    message: error.message || 'Une erreur est survenue.',
    data: null,
    error: {
      code: error.code || 'INTERNAL_ERROR',
      details: error.details || null,
    },
  });

const hierarchyService = {
  async getHierarchyOverview() {
    const [niveau0, niveau1, niveau2, niveau3, niveau4, niveau5] = await Promise.all([
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_0" ORDER BY "ID_Niveau_0" ASC LIMIT 50'),
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_1" ORDER BY "ID_Niveau_1" ASC LIMIT 50'),
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_2" ORDER BY "ID_Niveau_2" ASC LIMIT 50'),
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_3" ORDER BY "ID_Niveau_3" ASC LIMIT 50'),
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_4" ORDER BY "ID_Niveau_4" ASC LIMIT 50'),
      prisma.$queryRawUnsafe('SELECT * FROM geolocalisation."V_Niveau_5" ORDER BY "ID_Niveau_5" ASC LIMIT 50'),
    ]);

    return {
      niveau0,
      niveau1,
      niveau2,
      niveau3,
      niveau4,
      niveau5,
    };
  },

  async getChildren(level, id) {
    const normalizedId = parsePositiveInt(id, 'id');

    switch (String(level)) {
      case '0':
        return prisma.t_Niveau_1.findMany({ where: { ID_Niveau_0_Fk: normalizedId }, orderBy: { ID_Niveau_1: 'asc' } });
      case '1':
        return prisma.t_Niveau_2.findMany({ where: { ID_Niveau_1_FK: normalizedId }, orderBy: { ID_Niveau_2: 'asc' } });
      case '2':
        return prisma.t_Niveau_3.findMany({ where: { ID_Niveau_2_FK: normalizedId }, orderBy: { ID_Niveau_3: 'asc' } });
      case '3':
        return Promise.all([
          prisma.t_Niveau_4.findMany({ where: { ID_Niveau_3_Fk: normalizedId }, orderBy: { ID_Niveau_4: 'asc' } }),
          prisma.t_Niveau_5.findMany({ where: { ID_Niveau_3_Fk: normalizedId }, orderBy: { ID_Niveau_5: 'asc' } }),
        ]).then(([niveau4, niveau5]) => ({ niveau4, niveau5 }));
      case '4':
        return prisma.t_Niveau_5.findMany({ where: { ID_Niveau_4_Fk: normalizedId }, orderBy: { ID_Niveau_5: 'asc' } });
      default:
        throw createError('Niveau hierarchique non supporte.', 400, 'INVALID_LEVEL', { level });
    }
  },
};

const controller = {
  async getHierarchyOverview(req, res) {
    try {
      const data = await hierarchyService.getHierarchyOverview();
      return sendSuccess(res, 200, 'Hierarchie geolocalisation recuperee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async getChildren(req, res) {
    try {
      const data = await hierarchyService.getChildren(req.params.level, req.params.id);
      return sendSuccess(res, 200, 'Enfants hierarchiques recuperes avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
};

const router = express.Router();
router.get('/children/:level/:id', controller.getChildren);
router.get('/', controller.getHierarchyOverview);

module.exports = {
  router,
  controller,
  service: hierarchyService,
};
