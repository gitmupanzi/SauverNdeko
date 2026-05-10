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

const normalizeRequiredString = (value) => normalizeString(value);

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

const normalizeRequiredInt = (value) => {
  if (value === undefined || value === null || value === '') {
    return value;
  }

  return Number(value);
};

const assignOptionalBoolean = (source, target, fieldName) => {
  if (Object.prototype.hasOwnProperty.call(source, fieldName)) {
    target[fieldName] = normalizeOptionalBoolean(source[fieldName]);
  }
};

const toCreatePayload = (payload) => {
  const data = {
    ID_CategorieGeneriqueFk: normalizeRequiredInt(payload.ID_CategorieGeneriqueFk),
    NomGenerique: normalizeRequiredString(payload.NomGenerique),
  };

  if (Object.prototype.hasOwnProperty.call(payload, 'AbrGenerique')) {
    data.AbrGenerique = normalizeOptionalString(payload.AbrGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ObsGenerique')) {
    data.ObsGenerique = normalizeOptionalString(payload.ObsGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ValideGenerique')) {
    data.ValideGenerique = normalizeOptionalBoolean(payload.ValideGenerique);
  }

  assignOptionalBoolean(payload, data, 'VisibleNiveau_2');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_3');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_4');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_5');
  assignOptionalBoolean(payload, data, 'VisibleArticle');
  assignOptionalBoolean(payload, data, 'VisibleCmd');
  assignOptionalBoolean(payload, data, 'VisibleFacture');
  assignOptionalBoolean(payload, data, 'VisibleUsers');
  assignOptionalBoolean(payload, data, 'VisibleVoie');
  assignOptionalBoolean(payload, data, 'VisibleAll');

  return data;
};

const toUpdatePayload = (payload) => {
  const data = {};

  if (Object.prototype.hasOwnProperty.call(payload, 'ID_CategorieGeneriqueFk')) {
    data.ID_CategorieGeneriqueFk = normalizeRequiredInt(payload.ID_CategorieGeneriqueFk);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'NomGenerique')) {
    data.NomGenerique = normalizeRequiredString(payload.NomGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'AbrGenerique')) {
    data.AbrGenerique = normalizeOptionalString(payload.AbrGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ObsGenerique')) {
    data.ObsGenerique = normalizeOptionalString(payload.ObsGenerique);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'ValideGenerique')) {
    data.ValideGenerique = normalizeOptionalBoolean(payload.ValideGenerique);
  }

  assignOptionalBoolean(payload, data, 'VisibleNiveau_2');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_3');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_4');
  assignOptionalBoolean(payload, data, 'VisibleNiveau_5');
  assignOptionalBoolean(payload, data, 'VisibleArticle');
  assignOptionalBoolean(payload, data, 'VisibleCmd');
  assignOptionalBoolean(payload, data, 'VisibleFacture');
  assignOptionalBoolean(payload, data, 'VisibleUsers');
  assignOptionalBoolean(payload, data, 'VisibleVoie');
  assignOptionalBoolean(payload, data, 'VisibleAll');

  return data;
};

module.exports = {
  toCreatePayload,
  toUpdatePayload,
};
