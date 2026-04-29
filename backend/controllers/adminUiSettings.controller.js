const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { recordAdminAuditLog } = require('../utils/adminAudit');

const SETTING_KEY = 'fk-correspondance.standard';
const SETTING_SCOPE = 'global';
const ALLOWED_SETTING_SCOPES = new Set(['global', 'country', 'entity']);
const MANAGED_MAPPING_TYPES = ['generic_category', 'hierarchy_mode'];

const GENERIC_SOURCE_REGISTRY = {
  roles: {
    moduleName: 'admin',
    schemaName: 'referentiel',
    sourceKey: 'roles',
    fieldName: 'roles',
    fieldLabel: 'Role',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [39],
  },
  entityTypes: {
    moduleName: 'admin',
    schemaName: 'referentiel',
    sourceKey: 'entityTypes',
    fieldName: 'entityTypes',
    fieldLabel: 'Type entite',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [48],
  },
  licenseStatuses: {
    moduleName: 'admin',
    schemaName: 'referentiel',
    sourceKey: 'licenseStatuses',
    fieldName: 'licenseStatuses',
    fieldLabel: 'Statut licence',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [55],
  },
  niveau2Types: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau2Types',
    fieldName: 'niveau2Types',
    fieldLabel: 'Type niveau 2',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [32],
  },
  niveau3Types: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau3Types',
    fieldName: 'niveau3Types',
    fieldLabel: 'Type niveau 3',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [32],
  },
  niveau2Statuses: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau2Statuses',
    fieldName: 'niveau2Statuses',
    fieldLabel: 'Statut niveau 2',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [4],
  },
  niveau3Statuses: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau3Statuses',
    fieldName: 'niveau3Statuses',
    fieldLabel: 'Statut niveau 3',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [4],
  },
  deploymentStatuses: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'deploymentStatuses',
    fieldName: 'deploymentStatuses',
    fieldLabel: 'Statut deploiement',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [27],
  },
  dpsAccessRoutes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'dpsAccessRoutes',
    fieldName: 'dpsAccessRoutes',
    fieldLabel: 'Voie acces DPS',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [29],
  },
  antBczAccessRoutes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'antBczAccessRoutes',
    fieldName: 'antBczAccessRoutes',
    fieldLabel: 'Voie acces antenne BCZS',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [29],
  },
  dpsBczAccessRoutes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'dpsBczAccessRoutes',
    fieldName: 'dpsBczAccessRoutes',
    fieldLabel: 'Voie acces DPS BCZS',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [29],
  },
  niveau4Types: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau4Types',
    fieldName: 'niveau4Types',
    fieldLabel: 'Type niveau 4',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [32],
  },
  niveau5Types: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau5Types',
    fieldName: 'niveau5Types',
    fieldLabel: 'Type niveau 5',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [32],
  },
  niveau4Statuses: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau4Statuses',
    fieldName: 'niveau4Statuses',
    fieldLabel: 'Statut niveau 4',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [4],
  },
  niveau5Statuses: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveau5Statuses',
    fieldName: 'niveau5Statuses',
    fieldLabel: 'Statut niveau 5',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [4],
  },
  networkAvailabilities: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'networkAvailabilities',
    fieldName: 'networkAvailabilities',
    fieldLabel: 'Disponibilite reseau',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [19],
  },
  zsAsAccessRoutes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'zsAsAccessRoutes',
    fieldName: 'zsAsAccessRoutes',
    fieldLabel: 'Voie acces ZS-AS',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [29],
  },
  zsSiteAccessRoutes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'zsSiteAccessRoutes',
    fieldName: 'zsSiteAccessRoutes',
    fieldLabel: 'Voie acces ZS-Site',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [29],
  },
  roofTypes: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'roofTypes',
    fieldName: 'roofTypes',
    fieldLabel: 'Type de toit',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [18],
  },
  'logistique.articleTypes': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Article',
    sourceKey: 'logistique.articleTypes',
    fieldName: 'ID_TypeArticleFk',
    fieldLabel: "Type d'article",
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [46],
  },
  'logistique.articleCategories': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Article',
    sourceKey: 'logistique.articleCategories',
    fieldName: 'ID_CategorieArticleFk',
    fieldLabel: "Categorie d'article",
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [40],
  },
  'logistique.articleUnits': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Article',
    sourceKey: 'logistique.articleUnits',
    fieldName: 'ID_UniteFk',
    fieldLabel: 'Unite',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [34],
  },
  'logistique.commandeTypes': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    sourceKey: 'logistique.commandeTypes',
    fieldName: 'ID_TypeCmdFk',
    fieldLabel: 'Type de commande',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [64],
  },
  'logistique.commandeStatuses': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Commande',
    sourceKey: 'logistique.commandeStatuses',
    fieldName: 'ID_StatutCmdFk',
    fieldLabel: 'Statut commande',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [28],
  },
  'logistique.commandeConditionPaiements': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Commande',
    sourceKey: 'logistique.commandeConditionPaiements',
    fieldName: 'ID_ConditionPaiementFk',
    fieldLabel: 'Condition de paiement',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [37],
  },
  'logistique.commandeModesPaiement': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_Commande',
    sourceKey: 'logistique.commandeModesPaiement',
    fieldName: 'ID_ModePaiementFk',
    fieldLabel: 'Mode de paiement',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [36],
  },
  'logistique.reglementModes': {
    moduleName: 'logistique',
    schemaName: 'logistique',
    viewName: 'V_SuiviReglements',
    sourceKey: 'logistique.reglementModes',
    fieldName: 'ID_ModeReglementFk',
    fieldLabel: 'Mode de reglement',
    referenceSchemaName: 'referentiel',
    referenceObjectName: 'T_Generique',
    referenceFieldName: 'ID_Generique',
    defaultCategoryIds: [36],
  },
};

const HIERARCHY_SOURCE_REGISTRY = {
  niveaux0: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux0',
    fieldName: 'niveaux0',
    fieldLabel: 'Niveau 0',
    mappingType: 'hierarchy_mode',
    defaultMode: 'all',
  },
  niveaux1Old: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux1Old',
    fieldName: 'niveaux1Old',
    fieldLabel: 'Niveau 1 historique',
    mappingType: 'hierarchy_mode',
    defaultMode: 'all',
  },
  niveaux1: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux1',
    fieldName: 'niveaux1',
    fieldLabel: 'Niveau 1',
    mappingType: 'hierarchy_mode',
    defaultMode: 'filtered',
  },
  niveaux2: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux2',
    fieldName: 'niveaux2',
    fieldLabel: 'Niveau 2',
    mappingType: 'hierarchy_mode',
    defaultMode: 'filtered',
  },
  niveaux3: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux3',
    fieldName: 'niveaux3',
    fieldLabel: 'Niveau 3',
    mappingType: 'hierarchy_mode',
    defaultMode: 'filtered',
  },
  niveaux4: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux4',
    fieldName: 'niveaux4',
    fieldLabel: 'Niveau 4',
    mappingType: 'hierarchy_mode',
    defaultMode: 'filtered',
  },
  niveaux5: {
    moduleName: 'admin',
    schemaName: 'geolocalisation',
    sourceKey: 'niveaux5',
    fieldName: 'niveaux5',
    fieldLabel: 'Niveau 5',
    mappingType: 'hierarchy_mode',
    defaultMode: 'filtered',
  },
};

const ALL_SOURCE_REGISTRY = {
  ...GENERIC_SOURCE_REGISTRY,
  ...HIERARCHY_SOURCE_REGISTRY,
};

let ensureStoragePromise = null;

async function resolveExistingUserId(rawUserId) {
  const userId = Number(rawUserId);

  if (!Number.isInteger(userId) || userId <= 0) {
    return null;
  }

  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT u."IdUser"
      FROM systeme."T_Utilisateurs" u
      WHERE u."IdUser" = $1
      LIMIT 1;
    `,
    userId
  );

  return Array.isArray(rows) && rows[0]?.IdUser != null ? Number(rows[0].IdUser) : null;
}

function normalizeStringRecord(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  return Object.entries(value).reduce((accumulator, [key, entryValue]) => {
    const normalizedKey = String(key || '').trim();
    const normalizedValue = String(entryValue || '').trim();

    if (normalizedKey && normalizedValue) {
      accumulator[normalizedKey] = normalizedValue;
    }

    return accumulator;
  }, {});
}

function normalizeHierarchyModes(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  return Object.entries(value).reduce((accumulator, [key, entryValue]) => {
    const normalizedKey = String(key || '').trim();
    const normalizedValue = entryValue === 'all' ? 'all' : 'filtered';

    if (normalizedKey && normalizedValue !== 'filtered') {
      accumulator[normalizedKey] = normalizedValue;
    }

    return accumulator;
  }, {});
}

function sanitizeSettingsPayload(payload) {
  const value = payload && typeof payload === 'object' && !Array.isArray(payload) ? payload : {};

  return {
    genericCategoryOverrides: normalizeStringRecord(value.genericCategoryOverrides),
    hierarchyFilterModes: normalizeHierarchyModes(value.hierarchyFilterModes),
  };
}

function normalizeScopeInput(rawScope, rawScopeValue) {
  const scope = String(rawScope || SETTING_SCOPE).trim().toLowerCase();
  const normalizedScope = ALLOWED_SETTING_SCOPES.has(scope) ? scope : SETTING_SCOPE;
  const normalizedValue = rawScopeValue == null || rawScopeValue === '' ? null : String(rawScopeValue).trim();

  if (normalizedScope === 'global') {
    return {
      scope: normalizedScope,
      scopeValue: null,
    };
  }

  if (!normalizedValue) {
    return {
      scope: SETTING_SCOPE,
      scopeValue: null,
    };
  }

  return {
    scope: normalizedScope,
    scopeValue: normalizedValue || null,
  };
}

function parseCategoryOverrideInput(value) {
  const parts = String(value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  const parsed = [];

  for (const part of parts) {
    const number = Number(part);

    if (!Number.isInteger(number) || number <= 0) {
      return null;
    }

    if (!parsed.includes(number)) {
      parsed.push(number);
    }
  }

  return parsed;
}

function serializeCategoryIds(categoryIds) {
  return categoryIds.map((value) => String(value)).join(', ');
}

function resolveGenericCategoryIds(sourceKey, settings) {
  const config = GENERIC_SOURCE_REGISTRY[sourceKey];

  if (!config) {
    return [];
  }

  const overrideValue = settings.genericCategoryOverrides?.[sourceKey];
  const parsedOverride = parseCategoryOverrideInput(overrideValue);
  return parsedOverride && parsedOverride.length > 0 ? parsedOverride : config.defaultCategoryIds;
}

function resolveHierarchyMode(sourceKey, settings) {
  const config = HIERARCHY_SOURCE_REGISTRY[sourceKey];

  if (!config) {
    return 'filtered';
  }

  return settings.hierarchyFilterModes?.[sourceKey] === 'all' ? 'all' : config.defaultMode;
}

function buildRowsFromSettings(settings, scope, scopeValue, updatedByUserId = null, updatedAt = null) {
  const rows = [];
  const effectiveUpdatedAt = updatedAt || new Date();

  Object.entries(GENERIC_SOURCE_REGISTRY).forEach(([sourceKey, config]) => {
    const categoryIds = resolveGenericCategoryIds(sourceKey, settings);
    const isDefaultMapping = serializeCategoryIds(categoryIds) === serializeCategoryIds(config.defaultCategoryIds);

    categoryIds.forEach((categoryId, index) => {
      rows.push({
        ModuleName: config.moduleName,
        SchemaName: config.schemaName,
        ViewName: config.viewName || null,
        SourceKey: sourceKey,
        FieldName: config.fieldName,
        FieldLabel: config.fieldLabel,
        MappingType: 'generic_category',
        ReferenceSchemaName: config.referenceSchemaName || null,
        ReferenceObjectName: config.referenceObjectName || null,
        ReferenceFieldName: config.referenceFieldName || null,
        TargetCategoryIdFk: categoryId,
        MappingValue: String(categoryId),
        IsDefaultMapping: isDefaultMapping,
        ValideFkCorrespondance: true,
        SettingScope: scope,
        ScopeValue: scopeValue,
        DisplayOrder: index,
        UpdatedAt: effectiveUpdatedAt,
        UpdatedByUserFk: updatedByUserId,
        ObsFkCorrespondance: `Source ${sourceKey}`,
      });
    });
  });

  Object.entries(HIERARCHY_SOURCE_REGISTRY).forEach(([sourceKey, config]) => {
    const mode = resolveHierarchyMode(sourceKey, settings);

    rows.push({
      ModuleName: config.moduleName,
      SchemaName: config.schemaName,
      ViewName: config.viewName || null,
      SourceKey: sourceKey,
      FieldName: config.fieldName,
      FieldLabel: config.fieldLabel,
      MappingType: 'hierarchy_mode',
      ReferenceSchemaName: config.referenceSchemaName || null,
      ReferenceObjectName: config.referenceObjectName || null,
      ReferenceFieldName: config.referenceFieldName || null,
      TargetCategoryIdFk: null,
      MappingValue: mode,
      IsDefaultMapping: mode === config.defaultMode,
      ValideFkCorrespondance: true,
      SettingScope: scope,
      ScopeValue: scopeValue,
      DisplayOrder: 0,
      UpdatedAt: effectiveUpdatedAt,
      UpdatedByUserFk: updatedByUserId,
      ObsFkCorrespondance: `Source ${sourceKey}`,
    });
  });

  return rows;
}

function parseAuditPayload(rawValue) {
  if (!rawValue) {
    return null;
  }

  if (typeof rawValue === 'object') {
    return rawValue;
  }

  if (typeof rawValue !== 'string') {
    return null;
  }

  try {
    return JSON.parse(rawValue);
  } catch (_error) {
    return null;
  }
}

function formatResponseFromRows(rows, scope, scopeValue) {
  const safeRows = Array.isArray(rows) ? rows : [];
  const genericCategoryOverrides = {};
  const hierarchyFilterModes = {};

  Object.entries(GENERIC_SOURCE_REGISTRY).forEach(([sourceKey, config]) => {
    const sourceRows = safeRows
      .filter((row) => row.SourceKey === sourceKey && row.MappingType === 'generic_category')
      .sort((leftItem, rightItem) => {
        const leftOrder = Number(leftItem.DisplayOrder ?? 0);
        const rightOrder = Number(rightItem.DisplayOrder ?? 0);

        if (leftOrder !== rightOrder) {
          return leftOrder - rightOrder;
        }

        return Number(leftItem.MappingValue) - Number(rightItem.MappingValue);
      });

    const effectiveIds =
      sourceRows.length > 0
        ? sourceRows.map((row) => Number(row.MappingValue)).filter((value) => Number.isInteger(value) && value > 0)
        : config.defaultCategoryIds;

    const serializedCurrent = serializeCategoryIds(effectiveIds);
    const serializedDefault = serializeCategoryIds(config.defaultCategoryIds);

    if (serializedCurrent !== serializedDefault) {
      genericCategoryOverrides[sourceKey] = serializedCurrent;
    }
  });

  Object.entries(HIERARCHY_SOURCE_REGISTRY).forEach(([sourceKey, config]) => {
    const sourceRow = safeRows.find((row) => row.SourceKey === sourceKey && row.MappingType === 'hierarchy_mode');
    const currentMode = sourceRow?.MappingValue === 'all' ? 'all' : config.defaultMode;

    if (currentMode !== config.defaultMode) {
      hierarchyFilterModes[sourceKey] = currentMode;
    }
  });

  const latestRow = [...safeRows]
    .filter((row) => row.UpdatedAt)
    .sort((leftItem, rightItem) => new Date(rightItem.UpdatedAt) - new Date(leftItem.UpdatedAt))[0] || null;

  const updaterName = latestRow?.UpdatedByName || null;

  return {
    settingKey: SETTING_KEY,
    settingScope: scope || SETTING_SCOPE,
    scopeValue: scopeValue || null,
    genericCategoryOverrides,
    hierarchyFilterModes,
    updatedAt: latestRow?.UpdatedAt || null,
    updatedByUserId: latestRow?.UpdatedByUserFk ?? null,
    updatedByName: updaterName,
  };
}

async function insertFkRows(rows) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return;
  }

  await prisma.$transaction(
    rows.map((row) =>
      prisma.$executeRawUnsafe(
        `
          INSERT INTO systeme."T_Fk_Correspondance" (
            "ModuleName",
            "SchemaName",
            "ViewName",
            "SourceKey",
            "FieldName",
            "FieldLabel",
            "MappingType",
            "ReferenceSchemaName",
            "ReferenceObjectName",
            "ReferenceFieldName",
            "TargetCategoryIdFk",
            "MappingValue",
            "IsDefaultMapping",
            "ValideFkCorrespondance",
            "SettingScope",
            "ScopeValue",
            "DisplayOrder",
            "UpdatedAt",
            "UpdatedByUserFk",
            "ObsFkCorrespondance"
          )
          VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
            $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
          )
          ON CONFLICT ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue")
          DO UPDATE SET
            "FieldLabel" = EXCLUDED."FieldLabel",
            "ReferenceSchemaName" = EXCLUDED."ReferenceSchemaName",
            "ReferenceObjectName" = EXCLUDED."ReferenceObjectName",
            "ReferenceFieldName" = EXCLUDED."ReferenceFieldName",
            "TargetCategoryIdFk" = EXCLUDED."TargetCategoryIdFk",
            "IsDefaultMapping" = EXCLUDED."IsDefaultMapping",
            "ValideFkCorrespondance" = EXCLUDED."ValideFkCorrespondance",
            "DisplayOrder" = EXCLUDED."DisplayOrder",
            "UpdatedAt" = EXCLUDED."UpdatedAt",
            "UpdatedByUserFk" = EXCLUDED."UpdatedByUserFk",
            "ObsFkCorrespondance" = EXCLUDED."ObsFkCorrespondance";
        `,
        row.ModuleName,
        row.SchemaName,
        row.ViewName,
        row.SourceKey,
        row.FieldName,
        row.FieldLabel,
        row.MappingType,
        row.ReferenceSchemaName,
        row.ReferenceObjectName,
        row.ReferenceFieldName,
        row.TargetCategoryIdFk,
        row.MappingValue,
        row.IsDefaultMapping,
        row.ValideFkCorrespondance,
        row.SettingScope,
        row.ScopeValue,
        row.DisplayOrder,
        row.UpdatedAt,
        row.UpdatedByUserFk,
        row.ObsFkCorrespondance
      )
    )
  );
}

async function ensureAdminUiSettingsStorage() {
  if (!ensureStoragePromise) {
    ensureStoragePromise = (async () => {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS systeme."T_Fk_Correspondance"
        (
            "IdFkCorrespondance" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            "ModuleName" character varying(80) NOT NULL,
            "SchemaName" character varying(80) NOT NULL,
            "ViewName" character varying(120) NULL,
            "SourceKey" character varying(120) NOT NULL,
            "FieldName" character varying(120) NOT NULL,
            "FieldLabel" character varying(255) NULL,
            "MappingType" character varying(40) NOT NULL DEFAULT 'generic_category',
            "ReferenceSchemaName" character varying(80) NULL,
            "ReferenceObjectName" character varying(120) NULL,
            "ReferenceFieldName" character varying(120) NULL,
            "TargetCategoryIdFk" integer NULL,
            "MappingValue" character varying(120) NOT NULL,
            "IsDefaultMapping" boolean NOT NULL DEFAULT false,
            "ValideFkCorrespondance" boolean NOT NULL DEFAULT true,
            "SettingScope" character varying(60) NOT NULL DEFAULT 'global',
            "ScopeValue" character varying(120) NULL,
            "DisplayOrder" integer NOT NULL DEFAULT 0,
            "UpdatedAt" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
            "UpdatedByUserFk" integer NULL,
            "ObsFkCorrespondance" text NULL,
            CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue"),
            CONSTRAINT "Fk_FkCorrespondance_Category" FOREIGN KEY ("TargetCategoryIdFk")
                REFERENCES referentiel."T_CategorieGenerique" ("ID_CategorieGenerique")
                ON UPDATE CASCADE
                ON DELETE SET NULL,
            CONSTRAINT "Fk_FkCorrespondance_User" FOREIGN KEY ("UpdatedByUserFk")
                REFERENCES systeme."T_Utilisateurs" ("IdUser")
                ON UPDATE CASCADE
                ON DELETE SET NULL
        );
      `);

      await prisma.$executeRawUnsafe(`
        CREATE INDEX IF NOT EXISTS "idx_fkcorrespondance_source"
        ON systeme."T_Fk_Correspondance" ("SchemaName", "ViewName", "SourceKey");
      `);

      await prisma.$executeRawUnsafe(`
        CREATE INDEX IF NOT EXISTS "idx_fkcorrespondance_scope"
        ON systeme."T_Fk_Correspondance" ("SettingScope", "ScopeValue");
      `);

      await prisma.$executeRawUnsafe(`
        CREATE INDEX IF NOT EXISTS "idx_fkcorrespondance_updatedby"
        ON systeme."T_Fk_Correspondance" ("UpdatedByUserFk");
      `);
    })().catch((error) => {
      ensureStoragePromise = null;
      throw error;
    });
  }

  return ensureStoragePromise;
}

async function findSettingsRows(scope, scopeValue) {
  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT
        fc."IdFkCorrespondance",
        fc."ModuleName",
        fc."SchemaName",
        fc."ViewName",
        fc."SourceKey",
        fc."FieldName",
        fc."FieldLabel",
        fc."MappingType",
        fc."ReferenceSchemaName",
        fc."ReferenceObjectName",
        fc."ReferenceFieldName",
        fc."TargetCategoryIdFk",
        fc."MappingValue",
        fc."IsDefaultMapping",
        fc."ValideFkCorrespondance",
        fc."SettingScope",
        fc."ScopeValue",
        fc."DisplayOrder",
        fc."UpdatedAt",
        fc."UpdatedByUserFk",
        fc."ObsFkCorrespondance",
        u."NomUser",
        u."PrenomUser"
      FROM systeme."T_Fk_Correspondance" fc
      LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = fc."UpdatedByUserFk"
      WHERE fc."SettingScope" = $1
        AND (
          ($2::text IS NULL AND fc."ScopeValue" IS NULL)
          OR fc."ScopeValue" = $2::text
        )
        AND fc."MappingType" = ANY($3::text[])
        AND fc."ValideFkCorrespondance" = true
      ORDER BY fc."SourceKey" ASC, fc."DisplayOrder" ASC, fc."MappingValue" ASC;
    `,
    scope,
    scopeValue,
    MANAGED_MAPPING_TYPES
  );

  return Array.isArray(rows)
    ? rows.map((row) => ({
        ...row,
        UpdatedByName: [row.PrenomUser, row.NomUser].filter(Boolean).join(' ').trim() || null,
      }))
    : [];
}

async function replaceSettingsRows(scope, scopeValue, settings, userId) {
  const rows = buildRowsFromSettings(settings, scope, scopeValue, userId, new Date());

  await prisma.$transaction([
    prisma.$executeRawUnsafe(
      `
        DELETE FROM systeme."T_Fk_Correspondance"
        WHERE "SettingScope" = $1
          AND (
            ($2::text IS NULL AND "ScopeValue" IS NULL)
            OR "ScopeValue" = $2::text
          )
          AND "MappingType" = ANY($3::text[]);
      `,
      scope,
      scopeValue,
      MANAGED_MAPPING_TYPES
    ),
    ...rows.map((row) =>
      prisma.$executeRawUnsafe(
        `
          INSERT INTO systeme."T_Fk_Correspondance" (
            "ModuleName",
            "SchemaName",
            "ViewName",
            "SourceKey",
            "FieldName",
            "FieldLabel",
            "MappingType",
            "ReferenceSchemaName",
            "ReferenceObjectName",
            "ReferenceFieldName",
            "TargetCategoryIdFk",
            "MappingValue",
            "IsDefaultMapping",
            "ValideFkCorrespondance",
            "SettingScope",
            "ScopeValue",
            "DisplayOrder",
            "UpdatedAt",
            "UpdatedByUserFk",
            "ObsFkCorrespondance"
          )
          VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
            $11, $12, $13, $14, $15, $16, $17, CURRENT_TIMESTAMP, $18, $19
          );
        `,
        row.ModuleName,
        row.SchemaName,
        row.ViewName,
        row.SourceKey,
        row.FieldName,
        row.FieldLabel,
        row.MappingType,
        row.ReferenceSchemaName,
        row.ReferenceObjectName,
        row.ReferenceFieldName,
        row.TargetCategoryIdFk,
        row.MappingValue,
        row.IsDefaultMapping,
        row.ValideFkCorrespondance,
        row.SettingScope,
        row.ScopeValue,
        row.DisplayOrder,
        row.UpdatedByUserFk,
        row.ObsFkCorrespondance
      )
    ),
  ]);
}

function formatAuditRows(rows) {
  return (Array.isArray(rows) ? rows : []).map((row) => {
    const newData = parseAuditPayload(row.NewData);
    const oldData = parseAuditPayload(row.OldData);

    return {
      IdLog: row.IdLog,
      TableName: row.TableName,
      Operation: row.Operation,
      ChangedAt: row.ChangedAt,
      SettingScope: newData?.settingScope || oldData?.settingScope || 'global',
      ScopeValue: newData?.scopeValue ?? oldData?.scopeValue ?? null,
      UpdatedByName: newData?.updatedByName || oldData?.updatedByName || null,
      UpdatedByUserId: newData?.updatedByUserId ?? oldData?.updatedByUserId ?? null,
      UpdatedSettingAt: newData?.updatedAt || oldData?.updatedAt || null,
      OldData: row.OldData,
      NewData: row.NewData,
    };
  });
}

const getAdminUiSettings = catchAsync(async (req, res) => {
  await ensureAdminUiSettingsStorage();
  const { scope, scopeValue } = normalizeScopeInput(req.query.scope, req.query.scopeValue);
  const rows = await findSettingsRows(scope, scopeValue);

  res.json({
    success: true,
    data: {
      ...formatResponseFromRows(rows, scope, scopeValue),
      exists: rows.length > 0,
      requestedScope: scope,
      requestedScopeValue: scopeValue,
    },
  });
});

const updateAdminUiSettings = catchAsync(async (req, res) => {
  await ensureAdminUiSettingsStorage();

  const nextSettings = sanitizeSettingsPayload(req.body);
  const { scope, scopeValue } = normalizeScopeInput(req.body?.scope, req.body?.scopeValue);
  const updatedByUserId = await resolveExistingUserId(req.userId);
  const previousRows = await findSettingsRows(scope, scopeValue);
  const previousResponse = formatResponseFromRows(previousRows, scope, scopeValue);

  await replaceSettingsRows(scope, scopeValue, nextSettings, updatedByUserId);

  const nextRows = await findSettingsRows(scope, scopeValue);
  const nextResponse = formatResponseFromRows(nextRows, scope, scopeValue);

  await recordAdminAuditLog({
    tableName: 'T_Fk_Correspondance',
    operation: previousRows.length > 0 ? 'UPDATE' : 'CREATE',
    oldData: previousRows.length > 0 ? previousResponse : undefined,
    newData: nextResponse,
    idEntiteFk: req.adminUser?.IdEntiteFk ?? null,
  });

  res.json({
    success: true,
    data: {
      ...nextResponse,
      exists: true,
      requestedScope: scope,
      requestedScopeValue: scopeValue,
    },
    message: 'Parametrage FK partage enregistre.',
  });
});

const getAdminUiSettingsAudit = catchAsync(async (req, res) => {
  await ensureAdminUiSettingsStorage();

  const take = Math.max(1, Math.min(50, Number.parseInt(req.query.take, 10) || 12));
  const skip = Math.max(0, Number.parseInt(req.query.skip, 10) || 0);

  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT
        a."IdLog",
        a."TableName",
        a."Operation",
        a."ChangedAt",
        a."OldData",
        a."NewData"
      FROM systeme."T_Audit_Log" a
      WHERE a."TableName" = 'T_Fk_Correspondance'
      ORDER BY a."ChangedAt" DESC
      LIMIT $1 OFFSET $2;
    `,
    take,
    skip
  );

  res.json({
    success: true,
    data: formatAuditRows(rows),
  });
});

module.exports = {
  getAdminUiSettings,
  updateAdminUiSettings,
  getAdminUiSettingsAudit,
};
