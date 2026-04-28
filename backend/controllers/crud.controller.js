const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { recordAdminAuditLog } = require('../utils/adminAudit');
const {
  coercePrimaryKeyValue,
  getDelegateByModelName,
  getModelInfo,
  listModels,
  resolveModelName,
} = require('../utils/prismaMetadata');

const READABLE_MODELS = new Set([
  'T_CategorieGenerique',
  'T_Generique',
  'T_Entite_Localisation',
  'T_Niveau_0',
  'T_Niveau_1_Old',
  'T_Niveau_1',
  'T_Niveau_2',
  'T_Niveau_3',
  'T_Niveau_4',
  'T_Niveau_5',
]);
const WRITABLE_MODELS = new Set([
  'T_CategorieGenerique',
  'T_Generique',
  'T_Entite_Localisation',
  'T_Niveau_0',
  'T_Niveau_1_Old',
  'T_Niveau_1',
  'T_Niveau_2',
  'T_Niveau_3',
  'T_Niveau_4',
  'T_Niveau_5',
]);

const normalizeModelName = (value) => resolveModelName(value);

const ensureModelAccess = (modelName, mode = 'read') => {
  const allowedModels = mode === 'write' ? WRITABLE_MODELS : READABLE_MODELS;

  if (!allowedModels.has(modelName)) {
    const error = new Error(`Acces refuse au modele "${modelName}".`);
    error.statusCode = 403;
    throw error;
  }
};

const listAvailableModels = catchAsync(async (req, res) => {
  const models = listModels()
    .filter((model) => READABLE_MODELS.has(model.name))
    .map((model) => ({
      model: model.name,
      schema: model.schema || 'public',
      primaryKey: model.primaryKey,
      writable: WRITABLE_MODELS.has(model.name),
    }));

  res.json({
    success: true,
    data: models,
  });
});

const getAll = catchAsync(async (req, res) => {
  const modelName = normalizeModelName(req.params.model);
  ensureModelAccess(modelName, 'read');

  const delegate = getDelegateByModelName(prisma, modelName);
  const take = req.query.take ? Number(req.query.take) : undefined;
  const skip = req.query.skip ? Number(req.query.skip) : undefined;

  const data = await delegate.findMany({
    take: Number.isInteger(take) ? take : undefined,
    skip: Number.isInteger(skip) ? skip : undefined,
  });

  res.json({ success: true, data });
});

const getOne = catchAsync(async (req, res) => {
  const modelName = normalizeModelName(req.params.model);
  ensureModelAccess(modelName, 'read');

  const modelInfo = getModelInfo(modelName);
  const delegate = getDelegateByModelName(prisma, modelName);

  const data = await delegate.findUnique({
    where: {
      [modelInfo.primaryKey]: coercePrimaryKeyValue(modelInfo, req.params.id),
    },
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Enregistrement introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const create = catchAsync(async (req, res) => {
  const modelName = normalizeModelName(req.params.model);
  ensureModelAccess(modelName, 'write');

  const delegate = getDelegateByModelName(prisma, modelName);
  const data = await delegate.create({
    data: req.body,
  });

  await recordAdminAuditLog({
    tableName: modelName,
    operation: 'CREATE',
    newData: data,
  });

  res.status(201).json({ success: true, data });
});

const update = catchAsync(async (req, res) => {
  const modelName = normalizeModelName(req.params.model);
  ensureModelAccess(modelName, 'write');

  const modelInfo = getModelInfo(modelName);
  const delegate = getDelegateByModelName(prisma, modelName);
  const recordId = coercePrimaryKeyValue(modelInfo, req.params.id);
  const previous = await delegate.findUnique({
    where: {
      [modelInfo.primaryKey]: recordId,
    },
  });

  if (!previous) {
    return res.status(404).json({
      success: false,
      message: 'Enregistrement introuvable.',
    });
  }

  const data = await delegate.update({
    where: {
      [modelInfo.primaryKey]: recordId,
    },
    data: req.body,
  });

  await recordAdminAuditLog({
    tableName: modelName,
    operation: 'UPDATE',
    oldData: previous,
    newData: data,
  });

  res.json({ success: true, data });
});

const remove = catchAsync(async (req, res) => {
  const modelName = normalizeModelName(req.params.model);
  ensureModelAccess(modelName, 'write');

  const modelInfo = getModelInfo(modelName);
  const delegate = getDelegateByModelName(prisma, modelName);
  const recordId = coercePrimaryKeyValue(modelInfo, req.params.id);
  const previous = await delegate.findUnique({
    where: {
      [modelInfo.primaryKey]: recordId,
    },
  });

  if (!previous) {
    return res.status(404).json({
      success: false,
      message: 'Enregistrement introuvable.',
    });
  }

  const data = await delegate.delete({
    where: {
      [modelInfo.primaryKey]: recordId,
    },
  });

  await recordAdminAuditLog({
    tableName: modelName,
    operation: 'DELETE',
    oldData: previous,
  });

  res.json({ success: true, data });
});

module.exports = {
  create,
  getAll,
  getOne,
  listAvailableModels,
  remove,
  update,
};
