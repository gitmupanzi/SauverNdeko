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

const parseOptionalBoolean = (value, fieldName) => {
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

  throw createError(`Le champ ${fieldName} doit etre un booleen.`, 400, 'INVALID_BOOLEAN', {
    field: fieldName,
    value,
  });
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

  if (typeof payload.NomCategorieGenerique !== 'string' || !payload.NomCategorieGenerique.trim()) {
    throw createError('NomCategorieGenerique est obligatoire.', 400, 'INVALID_PAYLOAD', {
      field: 'NomCategorieGenerique',
    });
  }

  if (
    Object.prototype.hasOwnProperty.call(payload, 'ValideCategorieGenerique') &&
    typeof payload.ValideCategorieGenerique !== 'boolean' &&
    !['true', 'false'].includes(String(payload.ValideCategorieGenerique).trim().toLowerCase())
  ) {
    throw createError('ValideCategorieGenerique doit etre un booleen.', 400, 'INVALID_PAYLOAD', {
      field: 'ValideCategorieGenerique',
    });
  }
};

const validateUpdatePayload = (payload = {}) => {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    throw createError('Le corps de la requete est invalide.', 400, 'INVALID_PAYLOAD');
  }

  if (Object.keys(payload).length === 0) {
    throw createError('Aucune donnee a mettre a jour.', 400, 'INVALID_PAYLOAD');
  }

  if (
    Object.prototype.hasOwnProperty.call(payload, 'NomCategorieGenerique') &&
    (typeof payload.NomCategorieGenerique !== 'string' || !payload.NomCategorieGenerique.trim())
  ) {
    throw createError('NomCategorieGenerique ne peut pas etre vide.', 400, 'INVALID_PAYLOAD', {
      field: 'NomCategorieGenerique',
    });
  }

  if (
    Object.prototype.hasOwnProperty.call(payload, 'ValideCategorieGenerique') &&
    typeof payload.ValideCategorieGenerique !== 'boolean' &&
    !['true', 'false'].includes(String(payload.ValideCategorieGenerique).trim().toLowerCase())
  ) {
    throw createError('ValideCategorieGenerique doit etre un booleen.', 400, 'INVALID_PAYLOAD', {
      field: 'ValideCategorieGenerique',
    });
  }
};

module.exports = {
  createError,
  parsePositiveInt,
  validateListQuery,
  validateSearchQuery,
  validateCreatePayload,
  validateUpdatePayload,
};
