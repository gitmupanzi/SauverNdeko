const prisma = require('../config/db');

function sanitizeForAudit(value) {
  if (value === undefined) {
    return undefined;
  }

  if (value == null) {
    return null;
  }

  try {
    return JSON.parse(JSON.stringify(value));
  } catch (error) {
    return {
      value: String(value),
    };
  }
}

function resolveEntityId(record) {
  if (!record || typeof record !== 'object') {
    return null;
  }

  if (Number.isInteger(record.IdEntiteFk) && record.IdEntiteFk > 0) {
    return record.IdEntiteFk;
  }

  if (Number.isInteger(record.IdEntite) && record.IdEntite > 0) {
    return record.IdEntite;
  }

  return null;
}

async function resolveExistingEntityId(rawEntityId) {
  const entityId = Number(rawEntityId);

  if (!Number.isInteger(entityId) || entityId <= 0) {
    return null;
  }

  const rows = await prisma.$queryRawUnsafe(
    `
      SELECT e."IdEntite"
      FROM systeme."T_Entite" e
      WHERE e."IdEntite" = $1
      LIMIT 1;
    `,
    entityId
  );

  return Array.isArray(rows) && rows[0]?.IdEntite != null ? Number(rows[0].IdEntite) : null;
}

async function recordAdminAuditLog({
  tableName,
  operation,
  oldData,
  newData,
  idEntiteFk,
}) {
  try {
    const resolvedEntityId = await resolveExistingEntityId(
      Number.isInteger(idEntiteFk) && idEntiteFk > 0
        ? idEntiteFk
        : resolveEntityId(newData) || resolveEntityId(oldData) || null
    );

    const payload = {
      TableName: tableName,
      Operation: operation,
      IdEntiteFk: resolvedEntityId,
    };

    const normalizedOldData = sanitizeForAudit(oldData);
    const normalizedNewData = sanitizeForAudit(newData);

    if (normalizedOldData !== undefined) {
      payload.OldData = normalizedOldData;
    }

    if (normalizedNewData !== undefined) {
      payload.NewData = normalizedNewData;
    }

    await prisma.t_Audit_Log.create({
      data: payload,
    });
  } catch (error) {
    console.warn(`Impossible d'enregistrer l'audit admin sur ${tableName}.`, error.message);
  }
}

module.exports = {
  recordAdminAuditLog,
  resolveEntityId,
  resolveExistingEntityId,
  sanitizeForAudit,
};
