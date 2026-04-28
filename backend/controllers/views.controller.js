const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { getViewByName, listViews } = require('../utils/getPrismaViews');

const DEFAULT_TAKE = 25;
const MAX_TAKE = 200;

const parseTake = (value) => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    return DEFAULT_TAKE;
  }

  return Math.min(parsed, MAX_TAKE);
};

const parseSkip = (value) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : 0;
};

const quoteIdentifier = (value) => `"${String(value).replace(/"/g, '""')}"`;

const normalizeSearchText = (value) =>
  String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');

const parseFilters = (value) => {
  if (!value) {
    return {};
  }

  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (error) {
    return {};
  }
};

const getViewColumns = async (schema, viewName) => {
  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = $1 AND table_name = $2
      ORDER BY ordinal_position
    `,
    schema,
    viewName
  );

  return rows.map((row) => row.column_name);
};

const buildViewWhereClause = ({ columns, searchTerm, filters }) => {
  const conditions = [];
  const params = [];

  if (searchTerm) {
    const searchableColumns = columns.filter((column) => !/OldData|NewData/i.test(column));

    if (searchableColumns.length > 0) {
      params.push(`%${searchTerm}%`);
      const searchParamIndex = params.length;
      conditions.push(
        `(${searchableColumns
          .map((column) => `CAST(${quoteIdentifier(column)} AS text) ILIKE $${searchParamIndex}`)
          .join(' OR ')})`
      );
    }
  }

  Object.entries(filters).forEach(([column, rawValue]) => {
    if (!columns.includes(column)) {
      return;
    }

    if (Array.isArray(rawValue)) {
      const values = rawValue.map((value) => String(value).trim()).filter(Boolean);

      if (values.length === 0) {
        return;
      }

      const placeholders = values.map((value) => {
        params.push(value);
        return `$${params.length}`;
      });

      conditions.push(`CAST(${quoteIdentifier(column)} AS text) IN (${placeholders.join(', ')})`);
      return;
    }

    const value = String(rawValue || '').trim();

    if (!value) {
      return;
    }

    params.push(`%${value}%`);
    conditions.push(`CAST(${quoteIdentifier(column)} AS text) ILIKE $${params.length}`);
  });

  return {
    whereClause: conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '',
    params,
  };
};

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

  const columns = await getViewColumns(view.schema, view.name);
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const searchTerm = String(req.query.q || '').trim();
  const sortBy = columns.includes(req.query.sortBy) ? req.query.sortBy : columns[0] || null;
  const sortDir = String(req.query.sortDir || 'asc').toLowerCase() === 'desc' ? 'desc' : 'asc';
  const filters = parseFilters(req.query.filters);

  const { whereClause, params } = buildViewWhereClause({
    columns,
    searchTerm,
    filters,
  });

  const baseFromClause = `FROM ${quoteIdentifier(view.schema)}.${quoteIdentifier(view.name)}`;
  const orderClause = sortBy ? `ORDER BY ${quoteIdentifier(sortBy)} ${sortDir.toUpperCase()}` : '';

  const totalCountRows = await prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count ${baseFromClause}`);
  const filteredCountRows = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*)::int AS count ${baseFromClause} ${whereClause}`,
    ...params
  );

  const data = await prisma.$queryRawUnsafe(
    `SELECT * ${baseFromClause} ${whereClause} ${orderClause} LIMIT ${take} OFFSET ${skip}`,
    ...params
  );

  return res.json({
    success: true,
    data,
    meta: {
      columns,
      count: data.length,
      filteredCount: filteredCountRows?.[0]?.count || 0,
      totalCount: totalCountRows?.[0]?.count || 0,
      take,
      skip,
      sortBy,
      sortDir,
    },
  });
});

module.exports = {
  getView,
  listAvailableViews,
};
