const createError = (message, statusCode = 400, code = 'VALIDATION_ERROR', details = null) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  error.details = details;
  return error;
};

const parsePositiveInt = (value, fieldName) => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw createError(`Le champ ${fieldName} doit etre un entier positif.`, 400, 'INVALID_ID', {
      field: fieldName,
      value,
    });
  }

  return parsed;
};

const ensureBooleanLike = (value, fieldName) => {
  if (value === undefined) {
    return;
  }

  if (typeof value === 'boolean') {
    return;
  }

  if (typeof value === 'string') {
    const lowered = value.trim().toLowerCase();
    if (lowered === 'true' || lowered === 'false') {
      return;
    }
  }

  throw createError(`Le champ ${fieldName} doit etre un booleen.`, 400, 'INVALID_PAYLOAD', {
    field: fieldName,
    value,
  });
};

const parseOptionalBoolean = (value, fieldName) => {
  if (value === undefined) {
    return undefined;
  }

  ensureBooleanLike(value, fieldName);
  return String(value).trim().toLowerCase() === 'true' || value === true;
};

const validateListQuery = (query = {}) => {
  const take = query.take === undefined ? undefined : Number(query.take);
  const skip = query.skip === undefined ? undefined : Number(query.skip);

  if (take !== undefined && (!Number.isInteger(take) || take < 0)) {
    throw createError('Le parametre take doit etre un entier positif ou nul.', 400, 'INVALID_QUERY', {
      field: 'take',
      value: query.take,
    });
  }

  if (skip !== undefined && (!Number.isInteger(skip) || skip < 0)) {
    throw createError('Le parametre skip doit etre un entier positif ou nul.', 400, 'INVALID_QUERY', {
      field: 'skip',
      value: query.skip,
    });
  }

  return {
    take,
    skip,
    includeInactive: parseOptionalBoolean(query.includeInactive, 'includeInactive'),
  };
};

const validateSearchQuery = (query = {}) => {
  const filters = validateListQuery(query);
  const q = typeof query.q === 'string' ? query.q.trim() : '';

  if (!q) {
    throw createError('Le parametre q est obligatoire pour la recherche.', 400, 'INVALID_QUERY', {
      field: 'q',
    });
  }

  return {
    ...filters,
    q,
  };
};

const validateCreatePayload = (payload = {}) => {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    throw createError('Le corps de la requete est invalide.', 400, 'INVALID_PAYLOAD');
  }

  if (!Number.isInteger(Number(payload.ID_CategorieGeneriqueFk)) || Number(payload.ID_CategorieGeneriqueFk) <= 0) {
    throw createError('ID_CategorieGeneriqueFk est obligatoire.', 400, 'INVALID_PAYLOAD', {
      field: 'ID_CategorieGeneriqueFk',
    });
  }

  if (typeof payload.NomGenerique !== 'string' || !payload.NomGenerique.trim()) {
    throw createError('NomGenerique est obligatoire.', 400, 'INVALID_PAYLOAD', {
      field: 'NomGenerique',
    });
  }

  [
    'VisibleNiveau_2',
    'VisibleNiveau_3',
    'VisibleNiveau_4',
    'VisibleNiveau_5',
    'VisibleArticle',
    'VisibleCmd',
    'VisibleFacture',
    'VisibleUsers',
    'VisibleVoie',
    'VisibleAll',
    'ValideGenerique',
  ].forEach((fieldName) => ensureBooleanLike(payload[fieldName], fieldName));
};

const validateUpdatePayload = (payload = {}) => {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    throw createError('Le corps de la requete est invalide.', 400, 'INVALID_PAYLOAD');
  }

  if (Object.keys(payload).length === 0) {
    throw createError('Aucune donnee a mettre a jour.', 400, 'INVALID_PAYLOAD');
  }

  if (
    Object.prototype.hasOwnProperty.call(payload, 'ID_CategorieGeneriqueFk') &&
    (!Number.isInteger(Number(payload.ID_CategorieGeneriqueFk)) || Number(payload.ID_CategorieGeneriqueFk) <= 0)
  ) {
    throw createError('ID_CategorieGeneriqueFk doit etre un entier positif.', 400, 'INVALID_PAYLOAD', {
      field: 'ID_CategorieGeneriqueFk',
    });
  }

  if (
    Object.prototype.hasOwnProperty.call(payload, 'NomGenerique') &&
    (typeof payload.NomGenerique !== 'string' || !payload.NomGenerique.trim())
  ) {
    throw createError('NomGenerique ne peut pas etre vide.', 400, 'INVALID_PAYLOAD', {
      field: 'NomGenerique',
    });
  }

  [
    'VisibleNiveau_2',
    'VisibleNiveau_3',
    'VisibleNiveau_4',
    'VisibleNiveau_5',
    'VisibleArticle',
    'VisibleCmd',
    'VisibleFacture',
    'VisibleUsers',
    'VisibleVoie',
    'VisibleAll',
    'ValideGenerique',
  ].forEach((fieldName) => ensureBooleanLike(payload[fieldName], fieldName));
};

module.exports = {
  createError,
  parsePositiveInt,
  validateListQuery,
  validateSearchQuery,
  validateCreatePayload,
  validateUpdatePayload,
};
