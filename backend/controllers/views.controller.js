const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { getViewByName, listViews } = require('../utils/getPrismaViews');

const listAvailableViews = catchAsync(async (req, res) => {
  const views = await listViews(prisma);

  res.json({
    success: true,
    data: views,
  });
});

const getView = catchAsync(async (req, res) => {
  const view = await getViewByName(prisma, req.params.schema, req.params.view);

  if (!view) {
    return res.status(404).json({
      success: false,
      message: 'Vue introuvable.',
    });
  }

  const data = await prisma.$queryRawUnsafe(`SELECT * FROM "${view.schema}"."${view.name}"`);

  return res.json({
    success: true,
    data,
  });
});

module.exports = {
  getView,
  listAvailableViews,
};
