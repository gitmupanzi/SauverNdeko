const prisma = require('../config/db');
const { recordAdminAuditLog } = require('../utils/adminAudit');

const DEFAULT_TAKE = 25;
const MAX_TAKE = 200;
const NEAR_RUPTURE_MARGIN = 5;
const GENERIC_CATEGORY_IDS = {
  ARTICLE_TYPE: 46,
  ARTICLE_CATEGORY: 40,
  ARTICLE_UNIT: 34,
  COMMANDE_STATUS: 28,
  COMMANDE_TYPE: 64,
  CONDITION_PAIEMENT: 37,
  MODE_PAIEMENT: 36,
};

const LOGISTIQUE_GENERIC_FIELD_RULES = {
  article: {
    ID_TypeArticleFk: {
      categoryId: GENERIC_CATEGORY_IDS.ARTICLE_TYPE,
      categoryLabel: 'Type produit',
      fieldLabel: "Type d'article",
    },
    ID_CategorieArticleFk: {
      categoryId: GENERIC_CATEGORY_IDS.ARTICLE_CATEGORY,
      categoryLabel: 'Categorie produit',
      fieldLabel: "Categorie d'article",
    },
    ID_UniteFk: {
      categoryId: GENERIC_CATEGORY_IDS.ARTICLE_UNIT,
      categoryLabel: 'Unites',
      fieldLabel: 'Unite',
    },
  },
  commande: {
    ID_TypeCmdFk: {
      categoryId: GENERIC_CATEGORY_IDS.COMMANDE_TYPE,
      categoryLabel: 'Type de commande',
      fieldLabel: 'Type de commande',
    },
    ID_StatutCmdFk: {
      categoryId: GENERIC_CATEGORY_IDS.COMMANDE_STATUS,
      categoryLabel: 'Statut',
      fieldLabel: 'Statut de commande',
    },
    ID_ConditionPaiementFk: {
      categoryId: GENERIC_CATEGORY_IDS.CONDITION_PAIEMENT,
      categoryLabel: 'Condition de paiement',
      fieldLabel: 'Condition de paiement',
    },
    ID_ModePaiementFk: {
      categoryId: GENERIC_CATEGORY_IDS.MODE_PAIEMENT,
      categoryLabel: 'Mode paiement',
      fieldLabel: 'Mode de paiement',
    },
  },
  reglement: {
    ID_ModeReglementFk: {
      categoryId: GENERIC_CATEGORY_IDS.MODE_PAIEMENT,
      categoryLabel: 'Mode paiement',
      fieldLabel: 'Mode de reglement',
    },
  },
};

const VIEW_DEFINITIONS = {
  articles: {
    viewName: 'V_Article',
    searchColumns: ['NomArticle', 'RefArticle', 'CodeArticleInterne', 'NomComplet'],
    defaultOrderBy: 'ID_Article',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Article', 'NomArticle', 'QteArticle', 'PUArticle', 'PVArticle', 'ValideArticle'],
    filters: [
      { query: 'article', column: 'ID_Article', type: 'int' },
      { query: 'typeId', column: 'ID_TypeArticleFk', type: 'int' },
      { query: 'categorieId', column: 'ID_CategorieArticleFk', type: 'int' },
      { query: 'userId', column: 'IdUser', type: 'int' },
      { query: 'statut', column: 'ValideArticle', type: 'boolean' },
    ],
  },
  commandes: {
    viewName: 'V_Commande',
    searchColumns: ['CodeCmd', 'RefCmd', 'CodeFacture', 'NomUser', 'PrenomUser', 'NomComplet', 'StatusFacture'],
    defaultOrderBy: 'DateCmd',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Commande', 'DateCmd', 'CodeCmd', 'CodeFacture', 'MontantTTC', 'StatusFacture'],
    filters: [
      { query: 'commande', column: 'ID_Commande', type: 'int' },
      { query: 'typeId', column: 'ID_TypeCmdFk', type: 'int' },
      { query: 'statutId', column: 'ID_StatutCmdFk', type: 'int' },
      { query: 'client', column: 'ID_ClientFk', type: 'int' },
      { query: 'userId', column: 'ID_UserFk', type: 'int' },
      { query: 'code', column: 'CodeCmd', type: 'text' },
      { query: 'statut', column: 'StatusFacture', type: 'text' },
      { query: 'dateFrom', column: 'DateCmd', type: 'dateFrom' },
      { query: 'dateTo', column: 'DateCmd', type: 'dateTo' },
    ],
  },
  commandeDetails: {
    viewName: 'V_CommandeDetail',
    searchColumns: ['CodeCmd', 'CodeFacture', 'CodeArticleInterne', 'NomArticle', 'ObsCmdDetail'],
    defaultOrderBy: 'DateCmd',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_CmdFk', 'DateCmd', 'ID_ArticleFk', 'NomArticle', 'QteCmdDetail'],
    filters: [
      { query: 'commande', column: 'ID_CmdFk', type: 'int' },
      { query: 'article', column: 'ID_ArticleFk', type: 'int' },
      { query: 'typeId', column: 'ID_TypeCmdFk', type: 'int' },
      { query: 'statutId', column: 'ID_StatutCmdFk', type: 'int' },
      { query: 'dateFrom', column: 'DateCmd', type: 'dateFrom' },
      { query: 'dateTo', column: 'DateCmd', type: 'dateTo' },
    ],
  },
  mouvements: {
    viewName: 'V_Mouvement',
    searchColumns: ['TypeMvt', 'NomArticle', 'CodeCmd'],
    defaultOrderBy: 'DateMvt',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Mvt', 'DateMvt', 'ID_TypeMvtFk', 'ID_ArticleFk', 'ID_cmdFk', 'QteMvt', 'PUMvt'],
    filters: [
      { query: 'mouvement', column: 'ID_Mvt', type: 'int' },
      { query: 'typeId', column: 'ID_TypeMvtFk', type: 'int' },
      { query: 'article', column: 'ID_ArticleFk', type: 'int' },
      { query: 'commande', column: 'ID_cmdFk', type: 'int' },
      { query: 'dateFrom', column: 'DateMvt', type: 'dateFrom' },
      { query: 'dateTo', column: 'DateMvt', type: 'dateTo' },
    ],
  },
  auditStock: {
    viewName: 'V_AuditStock',
    searchColumns: ['CodeArticleInterne', 'NomArticle'],
    defaultOrderBy: 'Ecart',
    defaultOrderDir: 'asc',
    allowedSortColumns: ['ID_Article', 'NomArticle', 'StockArticle', 'StockMouvements', 'Ecart', 'N_Mouvements'],
    filters: [{ query: 'article', column: 'ID_Article', type: 'int' }],
  },
  alertesStock: {
    viewName: 'V_AlertStock',
    searchColumns: ['NomArticle'],
    defaultOrderBy: 'Marge',
    defaultOrderDir: 'asc',
    allowedSortColumns: ['ID_Article', 'NomArticle', 'QteArticle', 'QteMinArticle', 'Marge'],
    filters: [
      { query: 'article', column: 'ID_Article', type: 'int' },
      { query: 'criticalOnly', column: 'Marge', type: 'lte', value: 0 },
    ],
  },
  consommation: {
    viewName: 'V_ConsoMensuelle',
    searchColumns: ['NomArticle'],
    defaultOrderBy: 'Mois',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Article', 'NomArticle', 'Mois', 'ConsoMensuelle'],
    filters: [
      { query: 'article', column: 'ID_Article', type: 'int' },
      { query: 'dateFrom', column: 'Mois', type: 'dateFrom' },
      { query: 'dateTo', column: 'Mois', type: 'dateTo' },
    ],
  },
  couverture: {
    viewName: 'V_CouvertureStock',
    searchColumns: ['NomArticle'],
    defaultOrderBy: 'CouvertureMois',
    defaultOrderDir: 'asc',
    allowedSortColumns: ['ID_Article', 'NomArticle', 'StockActuel', 'ConsoMoyMensuelle', 'CouvertureMois'],
    filters: [{ query: 'article', column: 'ID_Article', type: 'int' }],
  },
  commandesSansDetails: {
    viewName: 'V_CommandesSansDetails',
    searchColumns: ['CodeCmd'],
    defaultOrderBy: 'ID_Commande',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Commande', 'CodeCmd'],
    filters: [
      { query: 'commande', column: 'ID_Commande', type: 'int' },
      { query: 'code', column: 'CodeCmd', type: 'text' },
    ],
  },
  reglements: {
    viewName: 'V_SuiviReglements',
    searchColumns: ['CodeFacture'],
    defaultOrderBy: 'ID_Commande',
    defaultOrderDir: 'desc',
    allowedSortColumns: ['ID_Commande', 'CodeFacture', 'MontantTTC', 'TotalRegle', 'Reste'],
    filters: [
      { query: 'commande', column: 'ID_Commande', type: 'int' },
      { query: 'codeFacture', column: 'CodeFacture', type: 'text' },
      { query: 'resteOnly', column: 'Reste', type: 'gt', value: 0 },
    ],
  },
};

const ARTICLE_INCLUDE = {
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
    },
  },
};

const COMMANDE_INCLUDE = {
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
    },
  },
  T_CommandeDetail: {
    include: {
      T_Article: {
        select: {
          ID_Article: true,
          NomArticle: true,
          PUArticle: true,
          PVArticle: true,
        },
      },
    },
  },
};

const COMMANDE_DETAIL_INCLUDE = {
  T_Commande: {
    select: {
      ID_Commande: true,
      CodeCmd: true,
      DateCmd: true,
      ID_TypeCmdFk: true,
      ID_StatutCmdFk: true,
    },
  },
  T_Article: {
    select: {
      ID_Article: true,
      NomArticle: true,
      QteArticle: true,
      PUArticle: true,
      PVArticle: true,
    },
  },
};

const REGLEMENT_INCLUDE = {
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
};

const quoteIdentifier = (value) => `"${String(value).replace(/"/g, '""')}"`;

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

const parseId = (value, label = 'identifiant') => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const normalizeString = (value) => {
  if (value == null) {
    return undefined;
  }

  const normalized = String(value).trim();
  return normalized === '' ? undefined : normalized;
};

const normalizeNullableString = (value) => {
  if (value == null) {
    return undefined;
  }

  return String(value).trim();
};

const normalizeBoolean = (value, fallback) => {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();

    if (['true', '1', 'oui', 'yes'].includes(normalized)) {
      return true;
    }

    if (['false', '0', 'non', 'no'].includes(normalized)) {
      return false;
    }
  }

  return fallback;
};

const normalizeDate = (value, label) => {
  if (value == null || value === '') {
    return undefined;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const calculateAlertDays = (datePeremption, dateAlerte) => {
  if (!datePeremption || !dateAlerte) {
    return null;
  }

  const peremptionUtc = Date.UTC(
    datePeremption.getUTCFullYear(),
    datePeremption.getUTCMonth(),
    datePeremption.getUTCDate()
  );
  const alerteUtc = Date.UTC(dateAlerte.getUTCFullYear(), dateAlerte.getUTCMonth(), dateAlerte.getUTCDate());
  const diffDays = Math.round((peremptionUtc - alerteUtc) / 86400000);

  if (diffDays < 0) {
    const error = new Error("La date d'alerte de peremption doit etre anterieure ou egale a la date de peremption.");
    error.statusCode = 400;
    throw error;
  }

  return diffDays;
};

const calculateAlertDateFromDays = (datePeremption, days) => {
  if (!datePeremption || days == null) {
    return null;
  }

  const alertDate = new Date(
    Date.UTC(datePeremption.getUTCFullYear(), datePeremption.getUTCMonth(), datePeremption.getUTCDate())
  );
  alertDate.setUTCDate(alertDate.getUTCDate() - days);
  return alertDate;
};

const normalizeTextForCompare = (value) =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();

const isCommandeLocked = (statusFacture) => normalizeTextForCompare(statusFacture) === 'cloturee';

const normalizeInteger = (value, label, options = {}) => {
  if (value == null || value === '') {
    return options.allowNull ? null : undefined;
  }

  return parseId(value, label);
};

const normalizeDecimal = (value, label, options = {}) => {
  if (value == null || value === '') {
    return options.allowNull ? null : undefined;
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  if (options.min != null && parsed < options.min) {
    const error = new Error(`${label} doit etre superieur ou egal a ${options.min}.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const ensureRecordExists = async (promise, message) => {
  const record = await promise;

  if (!record) {
    const error = new Error(message);
    error.statusCode = 404;
    throw error;
  }

  return record;
};

const ensureCommandeEditable = (commande, actionLabel = 'Cette commande') => {
  if (commande && isCommandeLocked(commande.StatusFacture)) {
    const error = new Error(`${actionLabel} est cloturee et ne peut plus etre modifiee.`);
    error.statusCode = 409;
    throw error;
  }

  return commande;
};

const buildListMeta = ({ data, take, skip, totalCount, filteredCount, sortBy, sortDir }) => ({
  count: data.length,
  take,
  skip,
  totalCount,
  filteredCount,
  sortBy,
  sortDir,
});

const normalizeForJson = (value) => {
  const isDecimalLike =
    value &&
    typeof value === 'object' &&
    typeof value.s === 'number' &&
    typeof value.e === 'number' &&
    Array.isArray(value.d);

  if (typeof value === 'bigint') {
    return value <= Number.MAX_SAFE_INTEGER && value >= Number.MIN_SAFE_INTEGER ? Number(value) : value.toString();
  }

  if (Array.isArray(value)) {
    return value.map((item) => normalizeForJson(item));
  }

  if (value instanceof Date || value == null) {
    return value;
  }

  if (typeof value === 'object') {
    if (isDecimalLike) {
      const chunks = value.d.map((chunk, index) => (index === 0 ? String(chunk) : String(chunk).padStart(7, '0')));
      const digits = chunks.join('');
      const decimalIndex = value.e + 1;
      let asString = digits;

      if (decimalIndex <= 0) {
        asString = `0.${'0'.repeat(Math.abs(decimalIndex))}${digits}`;
      } else if (decimalIndex < digits.length) {
        asString = `${digits.slice(0, decimalIndex)}.${digits.slice(decimalIndex)}`;
      } else if (decimalIndex > digits.length) {
        asString = `${digits}${'0'.repeat(decimalIndex - digits.length)}`;
      }

      if (value.s < 0) {
        asString = `-${asString}`;
      }

      const asNumber = Number(asString);
      return Number.isFinite(asNumber) ? asNumber : asString;
    }

    if (value.constructor?.name === 'Decimal' && typeof value.toJSON === 'function') {
      return value.toJSON();
    }

    return Object.fromEntries(
      Object.entries(value).map(([key, nestedValue]) => [key, normalizeForJson(nestedValue)])
    );
  }

  return value;
};

const appendCondition = (conditions, params, column, operator, value) => {
  params.push(value);
  conditions.push(`${quoteIdentifier(column)} ${operator} $${params.length}`);
};

const buildViewQuery = (definition, query = {}) => {
  const conditions = [];
  const params = [];
  const searchValue = normalizeString(query.q);

  if (searchValue && Array.isArray(definition.searchColumns) && definition.searchColumns.length > 0) {
    params.push(`%${searchValue}%`);
    const searchPlaceholder = `$${params.length}`;
    conditions.push(
      `(${definition.searchColumns
        .map((column) => `CAST(${quoteIdentifier(column)} AS text) ILIKE ${searchPlaceholder}`)
        .join(' OR ')})`
    );
  }

  for (const filter of definition.filters || []) {
    if (filter.type === 'lte' || filter.type === 'gt') {
      if (normalizeBoolean(query[filter.query], false)) {
        appendCondition(conditions, params, filter.column, filter.type === 'lte' ? '<=' : '>', filter.value);
      }

      continue;
    }

    const rawValue = query[filter.query];

    if (rawValue == null || rawValue === '') {
      continue;
    }

    if (filter.type === 'int') {
      appendCondition(conditions, params, filter.column, '=', parseId(rawValue, filter.query));
      continue;
    }

    if (filter.type === 'boolean') {
      appendCondition(conditions, params, filter.column, '=', normalizeBoolean(rawValue, false));
      continue;
    }

    if (filter.type === 'dateFrom') {
      appendCondition(conditions, params, filter.column, '>=', normalizeDate(rawValue, filter.query));
      continue;
    }

    if (filter.type === 'dateTo') {
      appendCondition(conditions, params, filter.column, '<=', normalizeDate(rawValue, filter.query));
      continue;
    }

    const normalizedValue = normalizeString(rawValue);

    if (!normalizedValue) {
      continue;
    }

    appendCondition(conditions, params, filter.column, 'ILIKE', `%${normalizedValue}%`);
  }

  const requestedSortBy = normalizeString(query.sortBy);
  const sortBy =
    requestedSortBy && definition.allowedSortColumns?.includes(requestedSortBy)
      ? requestedSortBy
      : definition.defaultOrderBy;
  const sortDir = String(query.sortDir || definition.defaultOrderDir || 'asc').toLowerCase() === 'desc' ? 'desc' : 'asc';

  return {
    whereClause: conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '',
    params,
    sortBy,
    sortDir,
  };
};

const queryViewList = async (viewKey, query = {}) => {
  const definition = VIEW_DEFINITIONS[viewKey];

  if (!definition) {
    const error = new Error(`Vue logistique inconnue: ${viewKey}.`);
    error.statusCode = 500;
    throw error;
  }

  const take = parseTake(query.take);
  const skip = parseSkip(query.skip);
  const { whereClause, params, sortBy, sortDir } = buildViewQuery(definition, query);
  const fromClause = `FROM logistique.${quoteIdentifier(definition.viewName)}`;
  const orderClause = sortBy ? `ORDER BY ${quoteIdentifier(sortBy)} ${sortDir.toUpperCase()}` : '';

  const [totalRows, filteredRows, data] = await Promise.all([
    prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count ${fromClause}`),
    prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count ${fromClause} ${whereClause}`, ...params),
    prisma.$queryRawUnsafe(
      `SELECT * ${fromClause} ${whereClause} ${orderClause} LIMIT ${take} OFFSET ${skip}`,
      ...params
    ),
  ]);

  return {
    data: normalizeForJson(data),
    meta: normalizeForJson(
      buildListMeta({
      data,
      take,
      skip,
      totalCount: totalRows?.[0]?.count || 0,
      filteredCount: filteredRows?.[0]?.count || 0,
      sortBy,
      sortDir,
      })
    ),
  };
};

const fetchGenericReferencesByCategory = (categoryId) =>
  prisma.$queryRawUnsafe(
    `
      SELECT
        g."ID_Generique" AS id,
        g."NomGenerique" AS label,
        g."AbrGenerique" AS abbr,
        g."ID_CategorieGeneriqueFk" AS "categoryId"
      FROM referentiel."T_Generique" g
      WHERE g."ID_CategorieGeneriqueFk" = $1
      ORDER BY COALESCE(NULLIF(trim(g."AbrGenerique"), ''), g."NomGenerique") ASC, g."ID_Generique" ASC
    `,
    categoryId
  );

const fetchClientReferences = async () => {
  const personneTableRows = await prisma.$queryRawUnsafe(`
    SELECT table_schema
    FROM information_schema.tables
    WHERE table_name = 'T_Personne'
    ORDER BY table_schema ASC
    LIMIT 1
  `);

  if (personneTableRows?.[0]?.table_schema) {
    const schemaName = String(personneTableRows[0].table_schema).replace(/"/g, '""');

    return prisma.$queryRawUnsafe(`
      SELECT
        p."ID_Personne" AS id,
        trim(
          both FROM concat(
            COALESCE(p."NomPersonne", ''),
            CASE
              WHEN COALESCE(p."NomPersonne", '') <> '' AND COALESCE(p."PrenomPersonne", '') <> '' THEN ' '
              ELSE ''
            END,
            COALESCE(p."PrenomPersonne", '')
          )
        ) AS label
      FROM ${quoteIdentifier(schemaName)}."T_Personne" p
      ORDER BY
        COALESCE(p."NomPersonne", '') ASC,
        COALESCE(p."PrenomPersonne", '') ASC,
        p."ID_Personne" ASC
    `);
  }

  return prisma.$queryRawUnsafe(`
    SELECT DISTINCT
      src.value::int AS id,
      COALESCE(NULLIF(trim(e."NomEntite"), ''), CONCAT('Client #', src.value::text)) AS label
    FROM (
      SELECT "ID_ClientFk" AS value FROM logistique."T_Commande"
      UNION
      SELECT "ID_ClientFk" AS value FROM logistique."T_Reglements"
    ) src
    LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = src.value
    WHERE src.value IS NOT NULL
    ORDER BY label ASC, id ASC
  `);
};

const buildGenericReferenceMeta = (referenceKey, sourceKey, rule) => ({
  referenceKey,
  sourceKey,
  locked: true,
  categoryIds: [rule.categoryId],
  categoryLabel: rule.categoryLabel,
  fieldLabel: rule.fieldLabel,
});

const ensureGenericValueMatchesCategory = async (value, rule) => {
  if (value == null) {
    return null;
  }

  const record = await prisma.t_Generique.findFirst({
    where: {
      ID_Generique: value,
      ID_CategorieGeneriqueFk: rule.categoryId,
    },
    select: {
      ID_Generique: true,
      ID_CategorieGeneriqueFk: true,
      NomGenerique: true,
    },
  });

  if (record) {
    return record;
  }

  const genericRecord = await prisma.t_Generique.findUnique({
    where: { ID_Generique: value },
    select: {
      ID_Generique: true,
      ID_CategorieGeneriqueFk: true,
      NomGenerique: true,
    },
  });

  if (!genericRecord) {
    const error = new Error(`${rule.fieldLabel} introuvable.`);
    error.statusCode = 400;
    throw error;
  }

  const error = new Error(
    `${rule.fieldLabel} invalide: la valeur #${value} appartient a la categorie ${genericRecord.ID_CategorieGeneriqueFk} et non a la categorie ${rule.categoryId} (${rule.categoryLabel}).`
  );
  error.statusCode = 400;
  throw error;
};

const ensureGenericPayloadMatchesRules = async (payload, rules = {}) => {
  await Promise.all(
    Object.entries(rules).map(async ([fieldName, rule]) => {
      if (!Object.prototype.hasOwnProperty.call(payload, fieldName)) {
        return;
      }

      await ensureGenericValueMatchesCategory(payload[fieldName], rule);
    })
  );
};

const getDashboardSummary = async () => {
  const [
    articleRows,
    articleHealthRows,
    commandeRows,
    commandeHealthRows,
    commandesSansDetailsRows,
    alertRows,
    factureRows,
    reglementRows,
    couvertureRows,
    consoRows,
    mouvementRows,
    topAlerts,
    topConso,
    topReglements,
    topCommandesSansDetails,
    topAuditEcarts,
    recentCommandes,
    expiringArticles,
    overdueCommandes,
    missingDocuments,
    recentMouvements,
  ] = await Promise.all([
    prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count FROM logistique."V_Article"`),
    prisma.$queryRawUnsafe(`
      SELECT
        COUNT(*) FILTER (WHERE COALESCE("ValideArticle", true) = true)::int AS "articlesActifs",
        COUNT(*) FILTER (WHERE COALESCE("ValideArticle", true) = false)::int AS "articlesInactifs",
        COUNT(*) FILTER (
          WHERE "DatePeremptionArticle" IS NOT NULL
            AND "DatePeremptionArticle" < CURRENT_TIMESTAMP
        )::int AS "articlesExpires",
        COUNT(*) FILTER (
          WHERE "DatePeremptionArticle" IS NOT NULL
            AND "DatePeremptionArticle" >= CURRENT_TIMESTAMP
            AND "DatePeremptionArticle" < CURRENT_TIMESTAMP + INTERVAL '30 days'
        )::int AS "articlesPeremption30j"
      FROM logistique."T_Article"
    `),
    prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count FROM logistique."V_Commande"`),
    prisma.$queryRawUnsafe(`
      SELECT
        COUNT(*) FILTER (WHERE COALESCE("MontantResteFacture", 0) > 0)::int AS "commandesOuvertes",
        COUNT(*) FILTER (
          WHERE "CodeFacture" IS NOT NULL
            AND COALESCE("MontantResteFacture", 0) <= 0
        )::int AS "commandesSoldees",
        COUNT(*) FILTER (
          WHERE "DateEcheancePaiement" IS NOT NULL
            AND "DateEcheancePaiement" < CURRENT_TIMESTAMP
            AND COALESCE("MontantResteFacture", 0) > 0
        )::int AS "facturesEnRetard",
        COUNT(*) FILTER (
          WHERE COALESCE(NULLIF(BTRIM("UrlBL"), ''), '') = ''
        )::int AS "blManquants",
        COUNT(*) FILTER (
          WHERE "CodeFacture" IS NOT NULL
            AND COALESCE(NULLIF(BTRIM("UrlFacture"), ''), '') = ''
        )::int AS "facturesSansUrl"
      FROM logistique."T_Commande"
    `),
    prisma.$queryRawUnsafe(`SELECT COUNT(*)::int AS count FROM logistique."V_CommandesSansDetails"`),
    prisma.$queryRawUnsafe(`
      SELECT
        COUNT(*) FILTER (WHERE "Marge" <= 0)::int AS "alertes",
        COUNT(*) FILTER (WHERE "Marge" > 0 AND "Marge" <= ${NEAR_RUPTURE_MARGIN})::int AS "prochesRupture"
      FROM logistique."V_AlertStock"
    `),
    prisma.$queryRawUnsafe(`
      SELECT COALESCE(SUM("MontantTTC"), 0)::numeric AS "totalFacture"
      FROM logistique."V_Commande"
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        COALESCE(SUM("TotalRegle"), 0)::numeric AS "totalRegle",
        COALESCE(SUM("Reste"), 0)::numeric AS "totalReste"
      FROM logistique."V_SuiviReglements"
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        COALESCE(AVG("CouvertureMois"), 0)::numeric AS "couvertureMoyenne",
        COALESCE(MIN("CouvertureMois"), 0)::numeric AS "couvertureMin",
        COUNT(*) FILTER (WHERE "CouvertureMois" IS NOT NULL AND "CouvertureMois" <= 1)::int AS "couvertureCritique"
      FROM logistique."V_CouvertureStock"
    `),
    prisma.$queryRawUnsafe(`
      SELECT COALESCE(SUM("ConsoMensuelle"), 0)::numeric AS "consommationMois"
      FROM logistique."V_ConsoMensuelle"
      WHERE date_trunc('month', "Mois") = date_trunc('month', CURRENT_DATE)
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        COUNT(*) FILTER (
          WHERE "DateMvt" >= date_trunc('month', CURRENT_DATE)
        )::int AS "mouvementsMois",
        COUNT(*) FILTER (
          WHERE "DateMvt" >= CURRENT_DATE - INTERVAL '7 days'
        )::int AS "mouvements7j",
        COALESCE(SUM("QteMvt") FILTER (
          WHERE "DateMvt" >= date_trunc('month', CURRENT_DATE)
        ), 0)::numeric AS "quantiteMouvementsMois"
      FROM logistique."T_Mouvement"
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_AlertStock"
      ORDER BY "Marge" ASC, "NomArticle" ASC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_ConsoMensuelle"
      WHERE date_trunc('month', "Mois") = date_trunc('month', CURRENT_DATE)
      ORDER BY "ConsoMensuelle" DESC, "NomArticle" ASC
      LIMIT 6
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_SuiviReglements"
      WHERE COALESCE("Reste", 0) > 0
      ORDER BY "Reste" DESC, "MontantTTC" DESC, "ID_Commande" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_CommandesSansDetails"
      ORDER BY "ID_Commande" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_AuditStock"
      WHERE COALESCE(ABS("Ecart"), 0) > 0
      ORDER BY ABS("Ecart") DESC, "ID_Article" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_Commande"
      ORDER BY "DateCmd" DESC NULLS LAST, "ID_Commande" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        "ID_Article",
        "NomArticle",
        "CodeArticleInterne",
        "DatePeremptionArticle",
        "QteArticle",
        "QteMinArticle"
      FROM logistique."T_Article"
      WHERE "DatePeremptionArticle" IS NOT NULL
        AND COALESCE("ValideArticle", true) = true
      ORDER BY "DatePeremptionArticle" ASC, "ID_Article" ASC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        "ID_Commande",
        "CodeCmd",
        "CodeFacture",
        "DateEcheancePaiement",
        "MontantTTC",
        "MontantResteFacture",
        "StatusFacture"
      FROM logistique."T_Commande"
      WHERE "DateEcheancePaiement" IS NOT NULL
        AND "DateEcheancePaiement" < CURRENT_TIMESTAMP
        AND COALESCE("MontantResteFacture", 0) > 0
      ORDER BY "DateEcheancePaiement" ASC, "MontantResteFacture" DESC, "ID_Commande" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT
        "ID_Commande",
        "CodeCmd",
        "CodeFacture",
        "DateCmd",
        "UrlBL",
        "UrlFacture",
        "StatusFacture"
      FROM logistique."T_Commande"
      WHERE COALESCE(NULLIF(BTRIM("UrlBL"), ''), '') = ''
         OR (
          "CodeFacture" IS NOT NULL
          AND COALESCE(NULLIF(BTRIM("UrlFacture"), ''), '') = ''
         )
      ORDER BY "DateCmd" DESC NULLS LAST, "ID_Commande" DESC
      LIMIT 5
    `),
    prisma.$queryRawUnsafe(`
      SELECT *
      FROM logistique."V_Mouvement"
      ORDER BY "DateMvt" DESC NULLS LAST, "ID_Mvt" DESC
      LIMIT 6
    `),
  ]);

  return normalizeForJson({
    totals: {
      articles: articleRows?.[0]?.count || 0,
      articlesActifs: articleHealthRows?.[0]?.articlesActifs || 0,
      articlesInactifs: articleHealthRows?.[0]?.articlesInactifs || 0,
      articlesExpires: articleHealthRows?.[0]?.articlesExpires || 0,
      articlesPeremption30j: articleHealthRows?.[0]?.articlesPeremption30j || 0,
      commandes: commandeRows?.[0]?.count || 0,
      commandesOuvertes: commandeHealthRows?.[0]?.commandesOuvertes || 0,
      commandesSoldees: commandeHealthRows?.[0]?.commandesSoldees || 0,
      facturesEnRetard: commandeHealthRows?.[0]?.facturesEnRetard || 0,
      blManquants: commandeHealthRows?.[0]?.blManquants || 0,
      facturesSansUrl: commandeHealthRows?.[0]?.facturesSansUrl || 0,
      commandesSansDetails: commandesSansDetailsRows?.[0]?.count || 0,
      alertesStock: alertRows?.[0]?.alertes || 0,
      prochesRupture: alertRows?.[0]?.prochesRupture || 0,
      montantTotalFacture: factureRows?.[0]?.totalFacture || 0,
      montantTotalRegle: reglementRows?.[0]?.totalRegle || 0,
      montantRestant: reglementRows?.[0]?.totalReste || 0,
      couvertureMoyenne: couvertureRows?.[0]?.couvertureMoyenne || 0,
      couvertureMinimale: couvertureRows?.[0]?.couvertureMin || 0,
      couvertureCritique: couvertureRows?.[0]?.couvertureCritique || 0,
      consommationMensuelle: consoRows?.[0]?.consommationMois || 0,
      mouvementsMois: mouvementRows?.[0]?.mouvementsMois || 0,
      mouvements7j: mouvementRows?.[0]?.mouvements7j || 0,
      quantiteMouvementsMois: mouvementRows?.[0]?.quantiteMouvementsMois || 0,
    },
    highlights: {
      alertes: topAlerts,
      consommation: topConso,
      reglements: topReglements,
      commandesSansDetails: topCommandesSansDetails,
      audit: topAuditEcarts,
      commandesRecentes: recentCommandes,
      peremption: expiringArticles,
      echeances: overdueCommandes,
      documentsManquants: missingDocuments,
      mouvementsRecents: recentMouvements,
    },
    assumptions: {
      procheRuptureMargeMax: NEAR_RUPTURE_MARGIN,
      peremptionWindowDays: 30,
    },
  });
};

const listReferences = async () => {
  let [
    articleTypes,
    articleCategories,
    articleUnits,
    commandeTypes,
    commandeStatuses,
    commandeConditionPaiements,
    commandeModesPaiement,
    reglementModes,
    users,
    clients,
    articles,
    factures,
  ] = await Promise.all([
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.ARTICLE_TYPE),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.ARTICLE_CATEGORY),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.ARTICLE_UNIT),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.COMMANDE_TYPE),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.COMMANDE_STATUS),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.CONDITION_PAIEMENT),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.MODE_PAIEMENT),
    fetchGenericReferencesByCategory(GENERIC_CATEGORY_IDS.MODE_PAIEMENT),
    prisma.t_Utilisateurs.findMany({
      select: {
        IdUser: true,
        NomUser: true,
        PrenomUser: true,
      },
      orderBy: [{ NomUser: 'asc' }, { PrenomUser: 'asc' }],
      take: 200,
    }),
    fetchClientReferences(),
    prisma.t_Article.findMany({
      select: {
        ID_Article: true,
        NomArticle: true,
        CodeArticleInterne: true,
        RefArticle: true,
        QteArticle: true,
        QteMinArticle: true,
        PUArticle: true,
        PVArticle: true,
      },
      orderBy: [{ NomArticle: 'asc' }],
      take: 1000,
    }),
    prisma.$queryRawUnsafe(`
      SELECT DISTINCT "CodeFacture" AS code
      FROM logistique."T_Commande"
      WHERE "CodeFacture" IS NOT NULL AND trim("CodeFacture") <> ''
      ORDER BY "CodeFacture" ASC
    `),
  ]);

  return {
    articleTypes,
    articleCategories,
    articleUnits,
    commandeTypes,
    commandeStatuses,
    commandeConditionPaiements,
    commandeModesPaiement,
    reglementModes,
    users: users.map((item) => ({
      id: item.IdUser,
      label: [item.NomUser, item.PrenomUser].filter(Boolean).join(' ').trim() || `Utilisateur #${item.IdUser}`,
    })),
    clients: clients.map((item) => ({
      id: item.id,
      label: item.label || `Client #${item.id}`,
    })),
    articles: articles.map((item) => ({
      id: item.ID_Article,
      label: item.NomArticle,
      code: item.CodeArticleInterne || item.RefArticle || null,
      reference: item.RefArticle || null,
      stock: item.QteArticle,
      minStock: item.QteMinArticle,
      purchasePrice: item.PUArticle,
      salePrice: item.PVArticle,
    })),
    factures: factures.map((item) => ({
      code: item.code,
      label: item.code,
    })),
    referenceMeta: {
      articleTypes: buildGenericReferenceMeta(
        'articleTypes',
        'logistique.articleTypes',
        LOGISTIQUE_GENERIC_FIELD_RULES.article.ID_TypeArticleFk
      ),
      articleCategories: buildGenericReferenceMeta(
        'articleCategories',
        'logistique.articleCategories',
        LOGISTIQUE_GENERIC_FIELD_RULES.article.ID_CategorieArticleFk
      ),
      articleUnits: buildGenericReferenceMeta(
        'articleUnits',
        'logistique.articleUnits',
        LOGISTIQUE_GENERIC_FIELD_RULES.article.ID_UniteFk
      ),
      commandeTypes: buildGenericReferenceMeta(
        'commandeTypes',
        'logistique.commandeTypes',
        LOGISTIQUE_GENERIC_FIELD_RULES.commande.ID_TypeCmdFk
      ),
      commandeStatuses: buildGenericReferenceMeta(
        'commandeStatuses',
        'logistique.commandeStatuses',
        LOGISTIQUE_GENERIC_FIELD_RULES.commande.ID_StatutCmdFk
      ),
      commandeConditionPaiements: buildGenericReferenceMeta(
        'commandeConditionPaiements',
        'logistique.commandeConditionPaiements',
        LOGISTIQUE_GENERIC_FIELD_RULES.commande.ID_ConditionPaiementFk
      ),
      commandeModesPaiement: buildGenericReferenceMeta(
        'commandeModesPaiement',
        'logistique.commandeModesPaiement',
        LOGISTIQUE_GENERIC_FIELD_RULES.commande.ID_ModePaiementFk
      ),
      reglementModes: buildGenericReferenceMeta(
        'reglementModes',
        'logistique.reglementModes',
        LOGISTIQUE_GENERIC_FIELD_RULES.reglement.ID_ModeReglementFk
      ),
    },
  };
};

const buildArticlePayload = (body, reqUserId, existingRecord = null) => {
  const payload = {};
  const nextNomArticle = normalizeNullableString(body.NomArticle);

  if (nextNomArticle !== undefined) {
    if (!nextNomArticle) {
      const error = new Error('NomArticle est obligatoire.');
      error.statusCode = 400;
      throw error;
    }

    payload.NomArticle = nextNomArticle;
  }

  if (!existingRecord && payload.NomArticle === undefined) {
    const error = new Error('NomArticle est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.ID_TypeArticleFk !== undefined) {
    payload.ID_TypeArticleFk = normalizeInteger(body.ID_TypeArticleFk, "Type d'article", { allowNull: true });
  }

  if (body.ID_CategorieArticleFk !== undefined) {
    payload.ID_CategorieArticleFk = normalizeInteger(body.ID_CategorieArticleFk, "Categorie d'article", { allowNull: true });
  }

  if (body.ID_UserFK !== undefined) {
    payload.ID_UserFK = normalizeInteger(body.ID_UserFK, 'Utilisateur', { allowNull: true });
  } else if (!existingRecord) {
    payload.ID_UserFK = reqUserId;
  }

  if (body.ID_UniteFk !== undefined) {
    payload.ID_UniteFk = normalizeInteger(body.ID_UniteFk, 'Unite', { allowNull: true });
  }

  if (body.CodeArticleExterne !== undefined) {
    payload.CodeArticleExterne = normalizeInteger(body.CodeArticleExterne, 'Code article externe', { allowNull: true });
  }

  if (body.RefArticle !== undefined) {
    payload.RefArticle = normalizeNullableString(body.RefArticle) || null;
  }

  if (body.QteArticle !== undefined) {
    payload.QteArticle = normalizeDecimal(body.QteArticle, 'Quantite article', { min: 0 });
  }

  if (body.PUArticle !== undefined) {
    payload.PUArticle = normalizeDecimal(body.PUArticle, "Prix d'achat", { min: 0 });
  }

  if (body.PVArticle !== undefined) {
    payload.PVArticle = normalizeDecimal(body.PVArticle, 'Prix de vente', { min: 0 });
  }

  if (!existingRecord && payload.PUArticle === undefined) {
    const error = new Error("PUArticle est obligatoire.");
    error.statusCode = 400;
    throw error;
  }

  if (!existingRecord && payload.PVArticle === undefined) {
    const error = new Error("PVArticle est obligatoire.");
    error.statusCode = 400;
    throw error;
  }

  if (body.QteMinArticle !== undefined) {
    payload.QteMinArticle = normalizeInteger(body.QteMinArticle, 'Quantite minimale', { allowNull: true });
  }

  if (body.PhotoArticle !== undefined) {
    payload.PhotoArticle = normalizeNullableString(body.PhotoArticle) || null;
  }

  if (body.ObsArticle !== undefined) {
    payload.ObsArticle = normalizeNullableString(body.ObsArticle) || null;
  }

  if (body.ValideArticle !== undefined) {
    payload.ValideArticle = normalizeBoolean(body.ValideArticle, existingRecord?.ValideArticle ?? true);
  }

  if (body.DatePeremptionArticle !== undefined) {
    payload.DatePeremptionArticle = normalizeDate(body.DatePeremptionArticle, 'Date de peremption') || null;
  }

  if (body.DatePeremptionAlerteArticle !== undefined) {
    payload.DatePeremptionAlerteArticle =
      normalizeDate(body.DatePeremptionAlerteArticle, "Date d'alerte de peremption") || null;
  }

  if (body.NbreJoursAlerteArticle !== undefined) {
    payload.NbreJoursAlerteArticle = normalizeInteger(body.NbreJoursAlerteArticle, "Nombre de jours d'alerte", {
      allowNull: true,
    });
  }

  const nextDatePeremption =
    Object.prototype.hasOwnProperty.call(payload, 'DatePeremptionArticle')
      ? payload.DatePeremptionArticle
      : existingRecord?.DatePeremptionArticle ?? null;
  const nextDateAlertePeremption =
    Object.prototype.hasOwnProperty.call(payload, 'DatePeremptionAlerteArticle')
      ? payload.DatePeremptionAlerteArticle
      : existingRecord?.DatePeremptionAlerteArticle ?? null;
  const nextAlertDays =
    Object.prototype.hasOwnProperty.call(payload, 'NbreJoursAlerteArticle')
      ? payload.NbreJoursAlerteArticle
      : existingRecord?.NbreJoursAlerteArticle ?? null;

  if (!nextDateAlertePeremption && nextDatePeremption && nextAlertDays != null) {
    payload.DatePeremptionAlerteArticle = calculateAlertDateFromDays(nextDatePeremption, nextAlertDays);
  }

  const resolvedDateAlertePeremption =
    Object.prototype.hasOwnProperty.call(payload, 'DatePeremptionAlerteArticle')
      ? payload.DatePeremptionAlerteArticle
      : nextDateAlertePeremption;

  if (
    Object.prototype.hasOwnProperty.call(payload, 'DatePeremptionArticle') ||
    Object.prototype.hasOwnProperty.call(payload, 'DatePeremptionAlerteArticle') ||
    body.NbreJoursAlerteArticle !== undefined
  ) {
    payload.NbreJoursAlerteArticle =
      nextDatePeremption && resolvedDateAlertePeremption
        ? calculateAlertDays(nextDatePeremption, resolvedDateAlertePeremption)
        : null;
  }

  if (body.CodeArticleInterne !== undefined) {
    payload.CodeArticleInterne = normalizeNullableString(body.CodeArticleInterne) || null;
  }

  return payload;
};

const buildCommandePayload = (body, reqUserId, existingRecord = null) => {
  const payload = {};

  if (body.ID_TypeCmdFk !== undefined) {
    payload.ID_TypeCmdFk = normalizeInteger(body.ID_TypeCmdFk, 'Type de commande', { allowNull: true });
  }

  if (!existingRecord && payload.ID_TypeCmdFk == null) {
    const error = new Error('ID_TypeCmdFk est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.ID_StatutCmdFk !== undefined) {
    payload.ID_StatutCmdFk = normalizeInteger(body.ID_StatutCmdFk, 'Statut de commande', { allowNull: true });
  }

  if (body.ID_ClientFk !== undefined) {
    payload.ID_ClientFk = normalizeInteger(body.ID_ClientFk, 'Client', { allowNull: true });
  }

  if (body.NomClientSaisi !== undefined) {
    payload.NomClientSaisi = normalizeNullableString(body.NomClientSaisi) || null;
  }

  if (body.ID_UserFk !== undefined) {
    payload.ID_UserFk = normalizeInteger(body.ID_UserFk, 'Utilisateur', { allowNull: true });
  } else if (!existingRecord) {
    payload.ID_UserFk = reqUserId;
  }

  if (body.geolocalisationCmd !== undefined) {
    payload.geolocalisationCmd = normalizeNullableString(body.geolocalisationCmd) || null;
  }

  if (body.DateCmd !== undefined) {
    payload.DateCmd = normalizeDate(body.DateCmd, 'Date commande') || null;
  } else if (!existingRecord) {
    payload.DateCmd = new Date();
  }

  if (body.CodeCmd !== undefined) {
    payload.CodeCmd = normalizeNullableString(body.CodeCmd) || null;
  }

  if (body.RefCmd !== undefined) {
    payload.RefCmd = normalizeNullableString(body.RefCmd) || null;
  }

  if (body.MontantHT !== undefined) {
    payload.MontantHT = normalizeDecimal(body.MontantHT, 'Montant HT', { allowNull: true, min: 0 });
  }

  if (body.MontantTTC !== undefined) {
    payload.MontantTTC = normalizeDecimal(body.MontantTTC, 'Montant TTC', { allowNull: true, min: 0 });
  }

  if (body.UrlBL !== undefined) {
    payload.UrlBL = normalizeNullableString(body.UrlBL) || null;
  }

  if (body.ObsCmd !== undefined) {
    payload.ObsCmd = normalizeNullableString(body.ObsCmd) || null;
  }

  if (body.SelectCmd !== undefined) {
    payload.SelectCmd = normalizeBoolean(body.SelectCmd, existingRecord?.SelectCmd ?? false);
  }

  if (body.DateFacture !== undefined) {
    payload.DateFacture = normalizeDate(body.DateFacture, 'Date facture') || null;
  }

  if (body.CodeFacture !== undefined) {
    payload.CodeFacture = normalizeNullableString(body.CodeFacture) || null;
  }

  if (body.MontantRegleFacture !== undefined) {
    payload.MontantRegleFacture = normalizeDecimal(body.MontantRegleFacture, 'Montant regle facture', {
      allowNull: true,
      min: 0,
    });
  }

  if (body.MontantResteFacture !== undefined) {
    payload.MontantResteFacture = normalizeDecimal(body.MontantResteFacture, 'Montant restant facture', {
      allowNull: true,
      min: 0,
    });
  }

  if (body.StatusFacture !== undefined) {
    payload.StatusFacture = normalizeNullableString(body.StatusFacture) || null;
  }

  if (body.ValideRemiseFacture !== undefined) {
    payload.ValideRemiseFacture = normalizeBoolean(
      body.ValideRemiseFacture,
      existingRecord?.ValideRemiseFacture ?? false
    );
  }

  if (body.UrlFacture !== undefined) {
    payload.UrlFacture = normalizeNullableString(body.UrlFacture) || null;
  }

  if (body.ID_ConditionPaiementFk !== undefined) {
    payload.ID_ConditionPaiementFk = normalizeInteger(body.ID_ConditionPaiementFk, 'Condition de paiement', {
      allowNull: true,
    });
  }

  if (body.DateEcheancePaiement !== undefined) {
    payload.DateEcheancePaiement = normalizeDate(body.DateEcheancePaiement, "Date d'echeance") || null;
  }

  if (body.ID_ModePaiementFk !== undefined) {
    payload.ID_ModePaiementFk = normalizeInteger(body.ID_ModePaiementFk, 'Mode de paiement', { allowNull: true });
  }

  return payload;
};

const buildCommandeDetailPayload = (body, options = {}) => {
  const payload = {};

  if (body.ID_ArticleFk !== undefined) {
    payload.ID_ArticleFk = normalizeInteger(body.ID_ArticleFk, 'Article');
  } else if (options.requireArticleId) {
    const error = new Error('ID_ArticleFk est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.QteCmdDetail !== undefined) {
    payload.QteCmdDetail = normalizeDecimal(body.QteCmdDetail, 'Quantite detail', { min: 0.001 });
  } else if (options.requireQuantity) {
    const error = new Error('QteCmdDetail est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.PUCmdDetail !== undefined) {
    payload.PUCmdDetail = normalizeDecimal(body.PUCmdDetail, 'Prix unitaire detail', { allowNull: true, min: 0 });
  }

  if (body.ObsCmdDetail !== undefined) {
    payload.ObsCmdDetail = normalizeNullableString(body.ObsCmdDetail) || null;
  }

  if (body.RemiseCmdDetail !== undefined) {
    payload.RemiseCmdDetail = normalizeBoolean(body.RemiseCmdDetail, false);
  }

  if (body.LieuCmdDetail !== undefined) {
    payload.LieuCmdDetail = normalizeInteger(body.LieuCmdDetail, 'Lieu detail', { allowNull: true });
  }

  if (body.SelectCmdDetail !== undefined) {
    payload.SelectCmdDetail = normalizeBoolean(body.SelectCmdDetail, false);
  }

  return payload;
};

const buildReglementPayload = (body, existingRecord = null) => {
  const payload = {};
  const nextCodeFacture = normalizeNullableString(body.CodeFactureFk);

  if (nextCodeFacture !== undefined) {
    if (!nextCodeFacture) {
      const error = new Error('CodeFactureFk est obligatoire.');
      error.statusCode = 400;
      throw error;
    }

    payload.CodeFactureFk = nextCodeFacture;
  }

  if (!existingRecord && payload.CodeFactureFk === undefined) {
    const error = new Error('CodeFactureFk est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.ID_ModeReglementFk !== undefined) {
    payload.ID_ModeReglementFk = normalizeInteger(body.ID_ModeReglementFk, 'Mode de reglement');
  }

  if (!existingRecord && payload.ID_ModeReglementFk === undefined) {
    const error = new Error('ID_ModeReglementFk est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  if (body.ID_ClientFk !== undefined) {
    payload.ID_ClientFk = normalizeInteger(body.ID_ClientFk, 'Client', { allowNull: true });
  }

  if (body.DateReglement !== undefined) {
    payload.DateReglement = normalizeDate(body.DateReglement, 'Date reglement') || null;
  } else if (!existingRecord) {
    payload.DateReglement = new Date();
  }

  if (body.MontantRegle !== undefined) {
    payload.MontantRegle = normalizeDecimal(body.MontantRegle, 'Montant regle', { min: 0 });
  }

  if (!existingRecord && payload.MontantRegle === undefined) {
    const error = new Error('MontantRegle est obligatoire.');
    error.statusCode = 400;
    throw error;
  }

  return payload;
};

const enrichArticleRows = async (result) => {
  const articleRows = Array.isArray(result?.data) ? result.data : [];

  if (articleRows.length === 0) {
    return result;
  }

  const articleIds = articleRows
    .map((row) => row?.ID_Article)
    .filter((value) => Number.isInteger(Number(value)))
    .map((value) => Number(value));

  if (articleIds.length === 0) {
    return result;
  }

  const records = await prisma.t_Article.findMany({
    where: {
      ID_Article: {
        in: articleIds,
      },
    },
    select: {
      ID_Article: true,
      PhotoArticle: true,
      DatePeremptionArticle: true,
      DatePeremptionAlerteArticle: true,
      NbreJoursAlerteArticle: true,
      ID_UserFK: true,
    },
  });

  const articleById = new Map(records.map((record) => [record.ID_Article, normalizeForJson(record)]));

  return {
    ...result,
    data: articleRows.map((row) => {
      const articleRecord = articleById.get(Number(row.ID_Article));

      if (!articleRecord) {
        return row;
      }

      return {
        ...row,
        PhotoArticle: articleRecord.PhotoArticle ?? row.PhotoArticle ?? null,
        DatePeremptionArticle: articleRecord.DatePeremptionArticle ?? row.DatePeremptionArticle ?? null,
        DatePeremptionAlerteArticle:
          articleRecord.DatePeremptionAlerteArticle ?? row.DatePeremptionAlerteArticle ?? null,
        NbreJoursAlerteArticle: articleRecord.NbreJoursAlerteArticle ?? row.NbreJoursAlerteArticle ?? null,
        ID_UserFK: articleRecord.ID_UserFK ?? row.ID_UserFK ?? null,
      };
    }),
  };
};

const enrichCommandeRows = async (result) => {
  const commandeRows = Array.isArray(result?.data) ? result.data : [];

  if (commandeRows.length === 0) {
    return result;
  }

  const commandeIds = commandeRows
    .map((row) => row?.ID_Commande)
    .filter((value) => Number.isInteger(Number(value)))
    .map((value) => Number(value));

  if (commandeIds.length === 0) {
    return result;
  }

  const records = await prisma.t_Commande.findMany({
    where: {
      ID_Commande: {
        in: commandeIds,
      },
    },
    select: {
      ID_Commande: true,
      NomClientSaisi: true,
    },
  });

  const commandeById = new Map(records.map((record) => [record.ID_Commande, normalizeForJson(record)]));

  return {
    ...result,
    data: commandeRows.map((row) => {
      const fallbackRecord = commandeById.get(Number(row.ID_Commande));

      if (!fallbackRecord) {
        return row;
      }

      return {
        ...fallbackRecord,
        ...row,
        NomClientSaisi: row.NomClientSaisi ?? fallbackRecord.NomClientSaisi ?? null,
      };
    }),
  };
};
const listArticles = async (query) => enrichArticleRows(await queryViewList('articles', query));
const listCommandes = async (query) => enrichCommandeRows(await queryViewList('commandes', query));
const listCommandeDetails = async (commandeId, query) =>
  queryViewList('commandeDetails', {
    ...query,
    commande: parseId(commandeId, 'commande'),
  });
const listMouvements = (query) => queryViewList('mouvements', query);
const listAuditStock = (query) => queryViewList('auditStock', query);
const listAlertesStock = (query) => queryViewList('alertesStock', query);
const listConsommation = (query) => queryViewList('consommation', query);
const listCouverture = (query) => queryViewList('couverture', query);
const listCommandesSansDetails = (query) => queryViewList('commandesSansDetails', query);
const listReglements = (query) => queryViewList('reglements', query);

const listReglementEntries = async (query = {}) => {
  const take = parseTake(query.take);
  const skip = parseSkip(query.skip);
  const codeFacture = normalizeString(query.codeFacture);
  const clientId = query.client ? parseId(query.client, 'client') : undefined;
  const dateFrom = query.dateFrom ? normalizeDate(query.dateFrom, 'dateFrom') : undefined;
  const dateTo = query.dateTo ? normalizeDate(query.dateTo, 'dateTo') : undefined;

  const where = {
    ...(codeFacture ? { CodeFactureFk: { contains: codeFacture, mode: 'insensitive' } } : {}),
    ...(clientId ? { ID_ClientFk: clientId } : {}),
    ...((dateFrom || dateTo)
      ? {
          DateReglement: {
            ...(dateFrom ? { gte: dateFrom } : {}),
            ...(dateTo ? { lte: dateTo } : {}),
          },
        }
      : {}),
  };

  const [data, totalCount] = await Promise.all([
    prisma.t_Reglements.findMany({
      where,
      include: REGLEMENT_INCLUDE,
      orderBy: [{ DateReglement: 'desc' }, { ID_Reglement: 'desc' }],
      take,
      skip,
    }),
    prisma.t_Reglements.count({ where }),
  ]);

  return {
    data: normalizeForJson(data),
    meta: normalizeForJson({
      count: data.length,
      filteredCount: totalCount,
      totalCount,
      take,
      skip,
    }),
  };
};

const createArticle = async (body, reqUserId) => {
  const payload = buildArticlePayload(body, reqUserId);
  payload.ID_UserFK = reqUserId;
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.article);
  const data = await prisma.t_Article.create({
    data: payload,
    include: ARTICLE_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Article',
    operation: 'CREATE',
    newData: data,
  });

  return data;
};

const updateArticle = async (articleId, body, reqUserId) => {
  const normalizedArticleId = parseId(articleId, 'article');
  const existingRecord = await ensureRecordExists(
    prisma.t_Article.findUnique({
      where: { ID_Article: normalizedArticleId },
    }),
    'Article introuvable.'
  );

  const payload = buildArticlePayload(body, reqUserId, existingRecord);
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.article);
  const data = await prisma.t_Article.update({
    where: { ID_Article: normalizedArticleId },
    data: payload,
    include: ARTICLE_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Article',
    operation: 'UPDATE',
    oldData: existingRecord,
    newData: data,
  });

  return data;
};

const removeArticle = async (articleId) => {
  const normalizedArticleId = parseId(articleId, 'article');
  const existingRecord = await ensureRecordExists(
    prisma.t_Article.findUnique({
      where: { ID_Article: normalizedArticleId },
    }),
    'Article introuvable.'
  );

  const data = await prisma.t_Article.update({
    where: { ID_Article: normalizedArticleId },
    data: {
      ValideArticle: false,
    },
    include: ARTICLE_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Article',
    operation: 'SOFT_DELETE',
    oldData: existingRecord,
    newData: data,
  });

  return data;
};

const createCommande = async (body, reqUserId) => {
  const payload = buildCommandePayload(body, reqUserId);
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.commande);
  const data = await prisma.t_Commande.create({
    data: payload,
    include: COMMANDE_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Commande',
    operation: 'CREATE',
    newData: data,
  });

  return data;
};

const updateCommande = async (commandeId, body, reqUserId) => {
  const normalizedCommandeId = parseId(commandeId, 'commande');
  const existingRecord = ensureCommandeEditable(
    await ensureRecordExists(
    prisma.t_Commande.findUnique({
      where: { ID_Commande: normalizedCommandeId },
    }),
    'Commande introuvable.'
    ),
    'Cette commande'
  );

  const payload = buildCommandePayload(body, reqUserId, existingRecord);
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.commande);
  const data = await prisma.t_Commande.update({
    where: { ID_Commande: normalizedCommandeId },
    data: payload,
    include: COMMANDE_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Commande',
    operation: 'UPDATE',
    oldData: existingRecord,
    newData: data,
  });

  return data;
};

const createCommandeDetail = async (commandeId, body) => {
  const normalizedCommandeId = parseId(commandeId, 'commande');
  const commande = ensureCommandeEditable(
    await ensureRecordExists(
    prisma.t_Commande.findUnique({
      where: { ID_Commande: normalizedCommandeId },
      select: { ID_Commande: true, StatusFacture: true },
    }),
    'Commande introuvable.'
    ),
    'Cette commande'
  );

  const payload = buildCommandeDetailPayload(body, {
    requireArticleId: true,
    requireQuantity: true,
  });

  await ensureRecordExists(
    prisma.t_Article.findUnique({
      where: { ID_Article: payload.ID_ArticleFk },
      select: { ID_Article: true },
    }),
    'Article introuvable.'
  );

  const data = await prisma.t_CommandeDetail.create({
    data: {
      ID_CmdFk: commande.ID_Commande,
      ...payload,
    },
    include: COMMANDE_DETAIL_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_CommandeDetail',
    operation: 'CREATE',
    newData: data,
  });

  return data;
};

const updateCommandeDetail = async (commandeId, articleId, body) => {
  const normalizedCommandeId = parseId(commandeId, 'commande');
  const normalizedArticleId = parseId(articleId, 'article');
  ensureCommandeEditable(
    await ensureRecordExists(
      prisma.t_Commande.findUnique({
        where: { ID_Commande: normalizedCommandeId },
        select: { ID_Commande: true, StatusFacture: true },
      }),
      'Commande introuvable.'
    ),
    'Cette commande'
  );
  const existingRecord = await ensureRecordExists(
    prisma.t_CommandeDetail.findUnique({
      where: {
        ID_ArticleFk_ID_CmdFk: {
          ID_ArticleFk: normalizedArticleId,
          ID_CmdFk: normalizedCommandeId,
        },
      },
      include: COMMANDE_DETAIL_INCLUDE,
    }),
    'Ligne de commande introuvable.'
  );

  const payload = buildCommandeDetailPayload(body);
  const nextArticleId = payload.ID_ArticleFk ?? normalizedArticleId;

  await ensureRecordExists(
    prisma.t_Article.findUnique({
      where: { ID_Article: nextArticleId },
      select: { ID_Article: true },
    }),
    'Article introuvable.'
  );

  const data = await prisma.$transaction(async (tx) => {
    if (nextArticleId !== normalizedArticleId) {
      await tx.t_CommandeDetail.delete({
        where: {
          ID_ArticleFk_ID_CmdFk: {
            ID_ArticleFk: normalizedArticleId,
            ID_CmdFk: normalizedCommandeId,
          },
        },
      });

      return tx.t_CommandeDetail.create({
        data: {
          ID_CmdFk: normalizedCommandeId,
          ID_ArticleFk: nextArticleId,
          QteCmdDetail: payload.QteCmdDetail ?? existingRecord.QteCmdDetail,
          PUCmdDetail: payload.PUCmdDetail ?? existingRecord.PUCmdDetail,
          ObsCmdDetail:
            Object.prototype.hasOwnProperty.call(payload, 'ObsCmdDetail') ? payload.ObsCmdDetail : existingRecord.ObsCmdDetail,
          RemiseCmdDetail:
            Object.prototype.hasOwnProperty.call(payload, 'RemiseCmdDetail')
              ? payload.RemiseCmdDetail
              : existingRecord.RemiseCmdDetail,
          LieuCmdDetail:
            Object.prototype.hasOwnProperty.call(payload, 'LieuCmdDetail') ? payload.LieuCmdDetail : existingRecord.LieuCmdDetail,
          SelectCmdDetail:
            Object.prototype.hasOwnProperty.call(payload, 'SelectCmdDetail')
              ? payload.SelectCmdDetail
              : existingRecord.SelectCmdDetail,
        },
        include: COMMANDE_DETAIL_INCLUDE,
      });
    }

    return tx.t_CommandeDetail.update({
        where: {
          ID_ArticleFk_ID_CmdFk: {
            ID_ArticleFk: normalizedArticleId,
            ID_CmdFk: normalizedCommandeId,
          },
        },
      data: payload,
      include: COMMANDE_DETAIL_INCLUDE,
    });
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_CommandeDetail',
    operation: 'UPDATE',
    oldData: existingRecord,
    newData: data,
  });

  return data;
};

const removeCommandeDetail = async (commandeId, articleId) => {
  const normalizedCommandeId = parseId(commandeId, 'commande');
  const normalizedArticleId = parseId(articleId, 'article');
  ensureCommandeEditable(
    await ensureRecordExists(
      prisma.t_Commande.findUnique({
        where: { ID_Commande: normalizedCommandeId },
        select: { ID_Commande: true, StatusFacture: true },
      }),
      'Commande introuvable.'
    ),
    'Cette commande'
  );
  const existingRecord = await ensureRecordExists(
    prisma.t_CommandeDetail.findUnique({
      where: {
        ID_ArticleFk_ID_CmdFk: {
          ID_ArticleFk: normalizedArticleId,
          ID_CmdFk: normalizedCommandeId,
        },
      },
      include: COMMANDE_DETAIL_INCLUDE,
    }),
    'Ligne de commande introuvable.'
  );

  await prisma.t_CommandeDetail.delete({
    where: {
      ID_ArticleFk_ID_CmdFk: {
        ID_ArticleFk: normalizedArticleId,
        ID_CmdFk: normalizedCommandeId,
      },
    },
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_CommandeDetail',
    operation: 'DELETE',
    oldData: existingRecord,
  });
};

const createReglement = async (body) => {
  const payload = buildReglementPayload(body);
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.reglement);

  const data = await prisma.t_Reglements.create({
    data: payload,
    include: REGLEMENT_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Reglements',
    operation: 'CREATE',
    newData: data,
  });

  return data;
};

const updateReglement = async (reglementId, body) => {
  const normalizedReglementId = parseId(reglementId, 'reglement');
  const existingRecord = await ensureRecordExists(
    prisma.t_Reglements.findUnique({
      where: { ID_Reglement: normalizedReglementId },
      include: REGLEMENT_INCLUDE,
    }),
    'Reglement introuvable.'
  );

  const payload = buildReglementPayload(body, existingRecord);
  await ensureGenericPayloadMatchesRules(payload, LOGISTIQUE_GENERIC_FIELD_RULES.reglement);

  const data = await prisma.t_Reglements.update({
    where: { ID_Reglement: normalizedReglementId },
    data: payload,
    include: REGLEMENT_INCLUDE,
  });

  await recordAdminAuditLog({
    tableName: 'logistique.T_Reglements',
    operation: 'UPDATE',
    oldData: existingRecord,
    newData: data,
  });

  return data;
};

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
  removeCommandeDetail,
  updateArticle,
  updateCommande,
  updateCommandeDetail,
  updateReglement,
};
