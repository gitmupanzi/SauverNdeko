const catchAsync = require('../middlewares/catchAsync');
const logistiqueService = require('../services/logistique.service');

const getDashboardSummary = catchAsync(async (req, res) => {
  const data = await logistiqueService.getDashboardSummary();
  res.json({ success: true, data });
});

const listReferences = catchAsync(async (req, res) => {
  const data = await logistiqueService.listReferences();
  res.json({ success: true, data });
});

const listArticles = catchAsync(async (req, res) => {
  const result = await logistiqueService.listArticles(req.query);
  res.json({ success: true, ...result });
});

const listCommandes = catchAsync(async (req, res) => {
  const result = await logistiqueService.listCommandes(req.query);
  res.json({ success: true, ...result });
});

const listCommandeDetails = catchAsync(async (req, res) => {
  const result = await logistiqueService.listCommandeDetails(Number(req.params.id), req.query);
  res.json({ success: true, ...result });
});

const listMouvements = catchAsync(async (req, res) => {
  const result = await logistiqueService.listMouvements(req.query);
  res.json({ success: true, ...result });
});

const listAuditStock = catchAsync(async (req, res) => {
  const result = await logistiqueService.listAuditStock(req.query);
  res.json({ success: true, ...result });
});

const listAlertesStock = catchAsync(async (req, res) => {
  const result = await logistiqueService.listAlertesStock(req.query);
  res.json({ success: true, ...result });
});

const listConsommation = catchAsync(async (req, res) => {
  const result = await logistiqueService.listConsommation(req.query);
  res.json({ success: true, ...result });
});

const listCouverture = catchAsync(async (req, res) => {
  const result = await logistiqueService.listCouverture(req.query);
  res.json({ success: true, ...result });
});

const listCommandesSansDetails = catchAsync(async (req, res) => {
  const result = await logistiqueService.listCommandesSansDetails(req.query);
  res.json({ success: true, ...result });
});

const listReglements = catchAsync(async (req, res) => {
  const result = await logistiqueService.listReglements(req.query);
  res.json({ success: true, ...result });
});

const listReglementEntries = catchAsync(async (req, res) => {
  const result = await logistiqueService.listReglementEntries(req.query);
  res.json({ success: true, ...result });
});

const createArticle = catchAsync(async (req, res) => {
  const data = await logistiqueService.createArticle(req.body, req.userId);
  res.status(201).json({ success: true, data });
});

const updateArticle = catchAsync(async (req, res) => {
  const data = await logistiqueService.updateArticle(Number(req.params.id), req.body, req.userId);
  res.json({ success: true, data });
});

const removeArticle = catchAsync(async (req, res) => {
  const hardDelete = String(req.query.mode || '').toLowerCase() === 'hard';
  const data = await logistiqueService.removeArticle(Number(req.params.id), { hardDelete });
  res.json({
    success: true,
    data,
    message: hardDelete ? 'Article supprime avec succes.' : 'Article desactive avec succes.',
  });
});

const createCommande = catchAsync(async (req, res) => {
  const data = await logistiqueService.createCommande(req.body, req.userId);
  res.status(201).json({ success: true, data });
});

const updateCommande = catchAsync(async (req, res) => {
  const data = await logistiqueService.updateCommande(Number(req.params.id), req.body, req.userId);
  res.json({ success: true, data });
});

const removeCommande = catchAsync(async (req, res) => {
  await logistiqueService.removeCommande(Number(req.params.id));
  res.json({
    success: true,
    message: 'Commande supprimee avec succes.',
  });
});

const createCommandeDetail = catchAsync(async (req, res) => {
  const data = await logistiqueService.createCommandeDetail(Number(req.params.id), req.body);
  res.status(201).json({ success: true, data });
});

const updateCommandeDetail = catchAsync(async (req, res) => {
  const data = await logistiqueService.updateCommandeDetail(
    Number(req.params.id),
    Number(req.params.articleId),
    req.body
  );
  res.json({ success: true, data });
});

const removeCommandeDetail = catchAsync(async (req, res) => {
  await logistiqueService.removeCommandeDetail(Number(req.params.id), Number(req.params.articleId));
  res.json({
    success: true,
    message: 'Ligne de commande supprimee avec succes.',
  });
});

const createReglement = catchAsync(async (req, res) => {
  const data = await logistiqueService.createReglement(req.body);
  res.status(201).json({ success: true, data });
});

const updateReglement = catchAsync(async (req, res) => {
  const data = await logistiqueService.updateReglement(Number(req.params.id), req.body);
  res.json({ success: true, data });
});

module.exports = {
  createArticle,
  createCommande,
  createCommandeDetail,
  createReglement,
  getDashboardSummary,
  listAlertesStock,
  listArticles,
  listAuditStock,
  listCommandeDetails,
  listCommandes,
  listCommandesSansDetails,
  listConsommation,
  listCouverture,
  listMouvements,
  listReferences,
  listReglementEntries,
  listReglements,
  removeArticle,
  removeCommande,
  removeCommandeDetail,
  updateArticle,
  updateCommande,
  updateCommandeDetail,
  updateReglement,
};
