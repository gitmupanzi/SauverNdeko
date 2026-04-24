const ALLOWED_SCHEMAS = [
  'analytics',
  'communication',
  'geolocalisation',
  'logistique',
  'operations',
  'professionnel',
  'referentiel',
  'systeme',
];

const listViews = async (prisma) => {
  const rows = await prisma.$queryRawUnsafe(`
    SELECT table_schema, table_name
    FROM information_schema.views
    WHERE table_schema IN (${ALLOWED_SCHEMAS.map((schema) => `'${schema}'`).join(', ')})
    ORDER BY table_schema, table_name
  `);

  return rows.map((row) => ({
    schema: row.table_schema,
    name: row.table_name,
  }));
};

const getViewByName = async (prisma, schema, viewName) => {
  if (!ALLOWED_SCHEMAS.includes(schema)) {
    return null;
  }

  const views = await prisma.$queryRawUnsafe(
    `
      SELECT table_schema, table_name
      FROM information_schema.views
      WHERE table_schema = $1 AND table_name = $2
      LIMIT 1
    `,
    schema,
    viewName
  );

  const view = views[0];

  if (!view) {
    return null;
  }

  return {
    schema: view.table_schema,
    name: view.table_name,
  };
};

module.exports = {
  getViewByName,
  listViews,
};
