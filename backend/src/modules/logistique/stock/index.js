const express = require('express');
const logistiqueService = require('../../../../services/logistique.service');

const service = {
  async getOverview(query = {}) {
    const [alertes, audit, consommation, couverture] = await Promise.all([
      logistiqueService.listAlertesStock(query),
      logistiqueService.listAuditStock(query),
      logistiqueService.listConsommation(query),
      logistiqueService.listCouverture(query),
    ]);

    return { alertes, audit, consommation, couverture };
  },
  alertes: (query) => logistiqueService.listAlertesStock(query),
  audit: (query) => logistiqueService.listAuditStock(query),
  consommation: (query) => logistiqueService.listConsommation(query),
  couverture: (query) => logistiqueService.listCouverture(query),
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
  async overview(req, res) {
    try {
      const data = await service.getOverview(req.query);
      return sendSuccess(res, 200, 'Vue stock recuperee avec succes.', data);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async alertes(req, res) {
    try {
      const result = await service.alertes(req.query);
      return sendSuccess(res, 200, 'Alertes stock recuperees avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async audit(req, res) {
    try {
      const result = await service.audit(req.query);
      return sendSuccess(res, 200, 'Audit stock recupere avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async consommation(req, res) {
    try {
      const result = await service.consommation(req.query);
      return sendSuccess(res, 200, 'Consommation stock recuperee avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
  async couverture(req, res) {
    try {
      const result = await service.couverture(req.query);
      return sendSuccess(res, 200, 'Couverture stock recuperee avec succes.', result.data ?? result);
    } catch (error) {
      return sendError(res, error);
    }
  },
};

const router = express.Router();
router.get('/alertes', controller.alertes);
router.get('/audit', controller.audit);
router.get('/consommation', controller.consommation);
router.get('/couverture', controller.couverture);
router.get('/', controller.overview);

module.exports = { router, controller, service, writeEnabled: false };
