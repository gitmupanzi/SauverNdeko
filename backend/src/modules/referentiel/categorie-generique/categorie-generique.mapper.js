const normalizeString = (value) => {
  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();
  return trimmed.length ? trimmed : '';
};

const normalizeOptionalString = (value) => {
  if (value === undefined) {
    return undefined;
  }

  if (value === null) {
    return null;
  }

  const trimmed = normalizeString(value);
  return trimmed === '' ? null : trimmed;
};

const normalizeOptionalBoolean = (value) => {
  if (value === undefined) {
    return undefined;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const lowered = value.trim().toLowerCase();

    if (lowered === 'true') {
      return true;
    }

    if (lowered === 'false') {
      return false;
    }
  }

  return value;
};

const toCreatePayload = (payload) => ({
  NomCategorieGenerique: normalizeOptionalString(payload.NomCategorieGenerique),
  ModuleCategorieGenerique: normalizeOptionalString(payload.ModuleCategorieGenerique),
  ValideCategorieGenerique: normalizeOptionalBoolean(payload.ValideCategorieGenerique),
});

const toUpdatePayload = (payload) => {
  const data = {};

  if (Object.prototype.hasOwnProperty.call(payload, 'NomCategorieGenerique')) {
    data.NomCategorieGenerique = normalizeOptionalString(payload.NomCategorieGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ModuleCategorieGenerique')) {
    data.ModuleCategorieGenerique = normalizeOptionalString(payload.ModuleCategorieGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ValideCategorieGenerique')) {
    data.ValideCategorieGenerique = normalizeOptionalBoolean(payload.ValideCategorieGenerique);
  }

  return data;
};

module.exports = {
  toCreatePayload,
  toUpdatePayload,
};
