const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { recordAdminAuditLog } = require('../utils/adminAudit');

const SETTING_KEY = 'admin-ui.select-settings';
const SETTING_SCOPE = 'global';
const ALLOWED_SETTING_SCOPES = new Set(['global', 'country', 'entity']);

let ensureStoragePromise = null;

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

function formatResponse(row) {
  const settings = sanitizeSettingsPayload(row?.SettingValue);
  const updaterName = [row?.PrenomUser, row?.NomUser].filter(Boolean).join(' ').trim();

  return {
    settingKey: row?.SettingKey || SETTING_KEY,
    settingScope: row?.SettingScope || SETTING_SCOPE,
    scopeValue: row?.ScopeValue || null,
    genericCategoryOverrides: settings.genericCategoryOverrides,
    hierarchyFilterModes: settings.hierarchyFilterModes,
    updatedAt: row?.UpdatedAt || null,
    updatedByUserId: row?.UpdatedByUserFk ?? null,
    updatedByName: updaterName || null,
  };
}

async function ensureAdminUiSettingsStorage() {
  if (!ensureStoragePromise) {
    ensureStoragePromise = (async () => {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS systeme."T_Admin_UI_Setting"
        (
            "IdAdminUiSetting" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            "SettingKey" character varying(120) NOT NULL,
            "SettingScope" character varying(60) NOT NULL DEFAULT 'global',
            "ScopeValue" character varying(120) NULL,
            "SettingValue" jsonb NOT NULL DEFAULT '{}'::jsonb,
            "UpdatedAt" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
            "UpdatedByUserFk" integer NULL,
            "ObsAdminUiSetting" text NULL,
            CONSTRAINT "UQ_AdminUiSetting_Scope" UNIQUE ("SettingKey", "SettingScope", "ScopeValue"),
            CONSTRAINT "Fk_AdminUiSetting_User" FOREIGN KEY ("UpdatedByUserFk")
                REFERENCES systeme."T_Utilisateurs" ("IdUser")
                ON UPDATE CASCADE
                ON DELETE SET NULL
        );
      `);

      await prisma.$executeRawUnsafe(`
        ALTER TABLE systeme."T_Admin_UI_Setting"
        ADD COLUMN IF NOT EXISTS "SettingScope" character varying(60) NOT NULL DEFAULT 'global';
      `);

      await prisma.$executeRawUnsafe(`
        ALTER TABLE systeme."T_Admin_UI_Setting"
        ADD COLUMN IF NOT EXISTS "ScopeValue" character varying(120) NULL;
      `);

      await prisma.$executeRawUnsafe(`
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = 'UQ_AdminUiSetting_SettingKey'
              AND conrelid = 'systeme."T_Admin_UI_Setting"'::regclass
          ) THEN
            ALTER TABLE systeme."T_Admin_UI_Setting"
            DROP CONSTRAINT "UQ_AdminUiSetting_SettingKey";
          END IF;
        END $$;
      `);

      await prisma.$executeRawUnsafe(`
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = 'UQ_AdminUiSetting_Scope'
              AND conrelid = 'systeme."T_Admin_UI_Setting"'::regclass
          ) THEN
            ALTER TABLE systeme."T_Admin_UI_Setting"
            ADD CONSTRAINT "UQ_AdminUiSetting_Scope"
            UNIQUE ("SettingKey", "SettingScope", "ScopeValue");
          END IF;
        END $$;
      `);

      await prisma.$executeRawUnsafe(`
        CREATE INDEX IF NOT EXISTS "idx_adminuisetting_updatedby"
        ON systeme."T_Admin_UI_Setting" ("UpdatedByUserFk");
      `);
    })().catch((error) => {
      ensureStoragePromise = null;
      throw error;
    });
  }

  return ensureStoragePromise;
}

async function findSettingsRow(scope, scopeValue) {
  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT s."SettingValue",
             s."SettingKey",
             s."SettingScope",
             s."ScopeValue",
             s."UpdatedAt",
             s."UpdatedByUserFk",
             u."NomUser",
             u."PrenomUser"
      FROM systeme."T_Admin_UI_Setting" s
      LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = s."UpdatedByUserFk"
      WHERE s."SettingKey" = $1
        AND s."SettingScope" = $2
        AND (
          ($3::text IS NULL AND s."ScopeValue" IS NULL)
          OR s."ScopeValue" = $3::text
        )
      LIMIT 1;
    `,
    SETTING_KEY,
    scope,
    scopeValue
  );

  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

const getAdminUiSettings = catchAsync(async (req, res) => {
  await ensureAdminUiSettingsStorage();
  const { scope, scopeValue } = normalizeScopeInput(req.query.scope, req.query.scopeValue);
  const row = await findSettingsRow(scope, scopeValue);

  res.json({
    success: true,
    data: {
      ...formatResponse(row),
      exists: Boolean(row),
      requestedScope: scope,
      requestedScopeValue: scopeValue,
    },
  });
});

const updateAdminUiSettings = catchAsync(async (req, res) => {
  await ensureAdminUiSettingsStorage();

  const nextSettings = sanitizeSettingsPayload(req.body);
  const { scope, scopeValue } = normalizeScopeInput(req.body?.scope, req.body?.scopeValue);
  const previousRow = await findSettingsRow(scope, scopeValue);

  await prisma.$executeRawUnsafe(
    `
      INSERT INTO systeme."T_Admin_UI_Setting" (
        "SettingKey",
        "SettingScope",
        "ScopeValue",
        "SettingValue",
        "UpdatedAt",
        "UpdatedByUserFk"
      )
      VALUES ($1, $2, $3, $4::jsonb, CURRENT_TIMESTAMP, $5)
      ON CONFLICT ("SettingKey", "SettingScope", "ScopeValue")
      DO UPDATE SET
        "SettingValue" = EXCLUDED."SettingValue",
        "UpdatedAt" = CURRENT_TIMESTAMP,
        "UpdatedByUserFk" = EXCLUDED."UpdatedByUserFk";
    `,
    SETTING_KEY,
    scope,
    scopeValue,
    JSON.stringify(nextSettings),
    Number.isInteger(req.userId) ? req.userId : null
  );

  const nextRow = await findSettingsRow(scope, scopeValue);

  await recordAdminAuditLog({
    tableName: 'T_Admin_UI_Setting',
    operation: previousRow ? 'UPDATE' : 'CREATE',
    oldData: previousRow ? formatResponse(previousRow) : undefined,
    newData: formatResponse(nextRow),
    idEntiteFk: req.adminUser?.IdEntiteFk ?? null,
  });

  res.json({
    success: true,
    data: {
      ...formatResponse(nextRow),
      exists: true,
      requestedScope: scope,
      requestedScopeValue: scopeValue,
    },
    message: 'Parametrage admin partage enregistre.',
  });
});

module.exports = {
  getAdminUiSettings,
  updateAdminUiSettings,
};
