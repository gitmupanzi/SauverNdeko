const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const {
  coercePrimaryKeyValue,
  getDelegateByModelName,
  getModelInfo,
  listModels,
  resolveModelName,
} = require('../utils/prismaMetadata');

const listAvailableModels = catchAsync(async (req, res) => {
  const models = listModels().map((model) => ({
    model: model.name,
    schema: model.schema || 'public',
    primaryKey: model.primaryKey,
  }));

  res.json({
    success: true,
    data: models,
  });
});

const getAll = catchAsync(async (req, res) => {
  const modelName = resolveModelName(req.params.model);
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
  const modelName = resolveModelName(req.params.model);
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
  const modelName = resolveModelName(req.params.model);
  const delegate = getDelegateByModelName(prisma, modelName);

  const data = await delegate.create({
    data: req.body,
  });

  res.status(201).json({ success: true, data });
});

const update = catchAsync(async (req, res) => {
  const modelName = resolveModelName(req.params.model);
  const modelInfo = getModelInfo(modelName);
  const delegate = getDelegateByModelName(prisma, modelName);

  const data = await delegate.update({
    where: {
      [modelInfo.primaryKey]: coercePrimaryKeyValue(modelInfo, req.params.id),
    },
    data: req.body,
  });

  res.json({ success: true, data });
});

const remove = catchAsync(async (req, res) => {
  const modelName = resolveModelName(req.params.model);
  const modelInfo = getModelInfo(modelName);
  const delegate = getDelegateByModelName(prisma, modelName);

  const data = await delegate.delete({
    where: {
      [modelInfo.primaryKey]: coercePrimaryKeyValue(modelInfo, req.params.id),
    },
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
