const express = require('express');
const logistiqueService = require('../../../../services/logistique.service');

const service = {
  async getDashboard() {
    return logistiqueService.getDashboardSummary();
  },
};

const controller = {
  async getDashboard(req, res) {
    try {
      const data = await service.getDashboard();
      return res.status(200).json({
        success: true,
        message: 'Dashboard logistique recupere avec succes.',
        data,
        error: null,
      });
    } catch (error) {
      return res.status(error.statusCode || 500).json({
        success: false,
        message: error.message || 'Une erreur est survenue',
        data: null,
        error: { code: error.code || 'INTERNAL_ERROR', details: error.details || null },
      });
    }
  },
};

const router = express.Router();
router.get('/', controller.getDashboard);

module.exports = { router, controller, service, writeEnabled: false };
