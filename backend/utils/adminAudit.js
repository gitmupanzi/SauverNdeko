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

async function recordAdminAuditLog({
  tableName,
  operation,
  oldData,
  newData,
  idEntiteFk,
}) {
  try {
    const payload = {
      TableName: tableName,
      Operation: operation,
      IdEntiteFk:
        Number.isInteger(idEntiteFk) && idEntiteFk > 0
          ? idEntiteFk
          : resolveEntityId(newData) || resolveEntityId(oldData) || null,
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
  sanitizeForAudit,
};
