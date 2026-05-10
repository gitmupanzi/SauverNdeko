const express = require('express');

const DEFAULT_TAKE = 100;
const MAX_TAKE = 500;

const createError = (message, statusCode = 400, code = 'VALIDATION_ERROR', details = null) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  error.details = details;
  return error;
};

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const parsePositiveInt = (value, fieldName = 'id') => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw createError(`Le champ ${fieldName} doit etre un entier positif.`, 400, 'INVALID_ID', {
      field: fieldName,
      value,
    });
  }

  return parsed;
};

const normalizeString = (value) => {
  if (typeof value !== 'string') {
    return value;
  }

  return value.trim();
};

const normalizeNullableString = (value) => {
  if (value === undefined) {
    return undefined;
  }

  if (value === null) {
    return null;
  }

  const normalized = normalizeString(String(value));
  return normalized === '' ? null : normalized;
};

const normalizeBoolean = (value, fieldName = 'field') => {
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

const normalizeInteger = (value, fieldName = 'field', { nullable = false } = {}) => {
  if (value === undefined) {
    return undefined;
  }

  if ((value === null || value === '') && nullable) {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isInteger(parsed)) {
    throw createError(`Le champ ${fieldName} doit etre un entier.`, 400, 'INVALID_INTEGER', {
      field: fieldName,
      value,
    });
  }

  return parsed;
};

const normalizeDecimal = (value, fieldName = 'field', { nullable = false, min } = {}) => {
  if (value === undefined) {
    return undefined;
  }

  if ((value === null || value === '') && nullable) {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    throw createError(`Le champ ${fieldName} doit etre numerique.`, 400, 'INVALID_DECIMAL', {
      field: fieldName,
      value,
    });
  }

  if (min !== undefined && parsed < min) {
    throw createError(`Le champ ${fieldName} doit etre superieur ou egal a ${min}.`, 400, 'INVALID_DECIMAL', {
      field: fieldName,
      value,
      min,
    });
  }

  return parsed;
};

const normalizeDate = (value, fieldName = 'field', { nullable = false } = {}) => {
  if (value === undefined) {
    return undefined;
  }

  if ((value === null || value === '') && nullable) {
    return null;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    throw createError(`Le champ ${fieldName} doit etre une date valide.`, 400, 'INVALID_DATE', {
      field: fieldName,
      value,
    });
  }

  return date;
};

const normalizeJson = (value) => {
  if (value === undefined) {
    return undefined;
  }

  return value;
};

const validateEmail = (value, fieldName = 'Email') => {
  const email = normalizeString(value);
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailRegex.test(email)) {
    throw createError(`Le champ ${fieldName} doit etre une adresse email valide.`, 400, 'INVALID_EMAIL', {
      field: fieldName,
      value,
    });
  }

  return email.toLowerCase();
};

const quoteIdentifier = (value) => `"${String(value).replace(/"/g, '""')}"`;
const quoteQualifiedName = (schemaName, objectName) => `${quoteIdentifier(schemaName)}.${quoteIdentifier(objectName)}`;
const escapeLiteral = (value) => `'${String(value).replace(/'/g, "''")}'`;
const escapeLike = (value) => String(value).replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_').replace(/'/g, "''");

const parseListQuery = (query = {}) => {
  const take = query.take === undefined ? DEFAULT_TAKE : normalizeInteger(query.take, 'take');
  const skip = query.skip === undefined ? 0 : normalizeInteger(query.skip, 'skip');

  if (take < 0 || take > MAX_TAKE) {
    throw createError(`Le parametre take doit etre compris entre 0 et ${MAX_TAKE}.`, 400, 'INVALID_QUERY', {
      field: 'take',
      value: query.take,
    });
  }

  if (skip < 0) {
    throw createError('Le parametre skip doit etre un entier positif ou nul.', 400, 'INVALID_QUERY', {
      field: 'skip',
      value: query.skip,
    });
  }

  const includeInactive =
    query.includeInactive === undefined ? false : normalizeBoolean(query.includeInactive, 'includeInactive');

  return {
    take,
    skip,
    includeInactive,
    q: typeof query.q === 'string' ? query.q.trim() : '',
  };
};

const ensureObjectPayload = (payload) => {
  if (!isObject(payload)) {
    throw createError('Le corps de la requete est invalide.', 400, 'INVALID_PAYLOAD');
  }
};

const validateFieldType = (fieldName, value, rule = {}, { required = false } = {}) => {
  if (value === undefined) {
    if (required) {
      throw createError(`${fieldName} est obligatoire.`, 400, 'INVALID_PAYLOAD', { field: fieldName });
    }

    return;
  }

  if ((value === null || value === '') && required && !rule.nullable) {
    throw createError(`${fieldName} est obligatoire.`, 400, 'INVALID_PAYLOAD', { field: fieldName });
  }

  switch (rule.type) {
    case 'string': {
      if (value !== null && typeof value !== 'string') {
        throw createError(`${fieldName} doit etre une chaine.`, 400, 'INVALID_PAYLOAD', { field: fieldName });
      }

      if (required && typeof value === 'string' && !value.trim()) {
        throw createError(`${fieldName} est obligatoire.`, 400, 'INVALID_PAYLOAD', { field: fieldName });
      }

      break;
    }
    case 'email':
      validateEmail(String(value), fieldName);
      break;
    case 'boolean':
      normalizeBoolean(value, fieldName);
      break;
    case 'int':
      normalizeInteger(value, fieldName, { nullable: Boolean(rule.nullable) });
      break;
    case 'decimal':
      normalizeDecimal(value, fieldName, { nullable: Boolean(rule.nullable), min: rule.min });
      break;
    case 'date':
      normalizeDate(value, fieldName, { nullable: Boolean(rule.nullable) });
      break;
    case 'json':
      break;
    default:
      break;
  }

  if (rule.enum && value !== null && value !== undefined) {
    if (!rule.enum.includes(String(value))) {
      throw createError(`${fieldName} contient une valeur invalide.`, 400, 'INVALID_PAYLOAD', {
        field: fieldName,
        value,
        allowed: rule.enum,
      });
    }
  }
};

const normalizeFieldValue = (fieldName, value, rule = {}) => {
  switch (rule.type) {
    case 'string':
      return rule.nullable ? normalizeNullableString(value) : normalizeString(String(value));
    case 'email':
      return validateEmail(String(value), fieldName);
    case 'boolean':
      return normalizeBoolean(value, fieldName);
    case 'int':
      return normalizeInteger(value, fieldName, { nullable: Boolean(rule.nullable) });
    case 'decimal':
      return normalizeDecimal(value, fieldName, { nullable: Boolean(rule.nullable), min: rule.min });
    case 'date':
      return normalizeDate(value, fieldName, { nullable: Boolean(rule.nullable) });
    case 'json':
      return normalizeJson(value);
    default:
      return value;
  }
};

const buildBasicValidation = (fieldRules = {}, { idLabel = 'id' } = {}) => ({
  parseId: (value) => parsePositiveInt(value, idLabel),
  validateListQuery: (query) => parseListQuery(query),
  validateSearchQuery: (query) => {
    const parsed = parseListQuery(query);

    if (!parsed.q) {
      throw createError('Le parametre q est obligatoire pour la recherche.', 400, 'INVALID_QUERY', {
        field: 'q',
      });
    }

    return parsed;
  },
  validateCreatePayload: (payload) => {
    ensureObjectPayload(payload);

    Object.entries(fieldRules).forEach(([fieldName, rule]) => {
      validateFieldType(fieldName, payload[fieldName], rule, { required: Boolean(rule.requiredOnCreate) });
    });
  },
  validateUpdatePayload: (payload) => {
    ensureObjectPayload(payload);

    if (Object.keys(payload).length === 0) {
      throw createError('Aucune donnee a mettre a jour.', 400, 'INVALID_PAYLOAD');
    }

    Object.entries(fieldRules).forEach(([fieldName, rule]) => {
      if (Object.prototype.hasOwnProperty.call(payload, fieldName)) {
        validateFieldType(fieldName, payload[fieldName], rule, { required: false });
      }
    });
  },
});

const buildBasicMapper = (fieldRules = {}, { createDefaults = {} } = {}) => ({
  toCreatePayload: (payload = {}) => {
    const data = {};

    Object.entries(fieldRules).forEach(([fieldName, rule]) => {
      if (Object.prototype.hasOwnProperty.call(payload, fieldName)) {
        data[fieldName] = normalizeFieldValue(fieldName, payload[fieldName], rule);
      } else if (Object.prototype.hasOwnProperty.call(createDefaults, fieldName)) {
        const defaultValue =
          typeof createDefaults[fieldName] === 'function' ? createDefaults[fieldName](payload) : createDefaults[fieldName];
        data[fieldName] = defaultValue;
      }
    });

    return data;
  },
  toUpdatePayload: (payload = {}) => {
    const data = {};

    Object.entries(fieldRules).forEach(([fieldName, rule]) => {
      if (Object.prototype.hasOwnProperty.call(payload, fieldName)) {
        data[fieldName] = normalizeFieldValue(fieldName, payload[fieldName], rule);
      }
    });

    return data;
  },
});

class TableRepository {
  constructor(prisma, config) {
    this.prisma = prisma;
    this.config = config;
    this.delegate = prisma[config.delegateName];

    if (!this.delegate) {
      throw new Error(`Delegate Prisma introuvable: ${config.delegateName}`);
    }
  }

  buildTableWhere(filters = {}) {
    const where = { ...(this.config.baseWhere || {}) };

    if (this.config.softDeleteField && !filters.includeInactive) {
      where[this.config.softDeleteField] = true;
    }

    if (filters.q && Array.isArray(this.config.tableSearchFields) && this.config.tableSearchFields.length > 0) {
      where.OR = this.config.tableSearchFields.map((fieldName) => ({
        [fieldName]: {
          contains: filters.q,
          mode: 'insensitive',
        },
      }));
    }

    if (typeof this.config.extendTableWhere === 'function') {
      return this.config.extendTableWhere(where, filters);
    }

    return where;
  }

  findMany(filters = {}) {
    return this.delegate.findMany({
      where: this.buildTableWhere(filters),
      take: filters.take,
      skip: filters.skip,
      orderBy: this.config.orderBy || { [this.config.idField]: 'asc' },
      include: this.config.include,
    });
  }

  findById(id) {
    return this.delegate.findUnique({
      where: { [this.config.idField]: id },
      include: this.config.include,
    });
  }

  create(data) {
    return this.delegate.create({
      data,
      include: this.config.include,
    });
  }

  update(id, data) {
    return this.delegate.update({
      where: { [this.config.idField]: id },
      data,
      include: this.config.include,
    });
  }

  delete(id) {
    return this.delegate.delete({
      where: { [this.config.idField]: id },
    });
  }

  softDelete(id) {
    return this.delegate.update({
      where: { [this.config.idField]: id },
      data: { [this.config.softDeleteField]: false },
      include: this.config.include,
    });
  }
}

class ViewRepository {
  constructor(prisma, config) {
    this.prisma = prisma;
    this.config = config;
  }

  buildWhereClause(filters = {}) {
    const clauses = [];

    if (this.config.activeField && !filters.includeInactive) {
      clauses.push(`${quoteIdentifier(this.config.activeField)} IS DISTINCT FROM FALSE`);
    }

    if (filters.q && Array.isArray(this.config.searchColumns) && this.config.searchColumns.length > 0) {
      const escaped = escapeLike(filters.q);
      clauses.push(
        `(${this.config.searchColumns
          .map((columnName) => `CAST(${quoteIdentifier(columnName)} AS TEXT) ILIKE '%${escaped}%' ESCAPE '\\'`)
          .join(' OR ')})`
      );
    }

    if (Array.isArray(this.config.filters)) {
      this.config.filters.forEach((filter) => {
        if (!Object.prototype.hasOwnProperty.call(filters, filter.query)) {
          return;
        }

        const value = filters[filter.query];

        if (value === undefined || value === null || value === '') {
          return;
        }

        if (filter.type === 'int') {
          clauses.push(`${quoteIdentifier(filter.column)} = ${Number(value)}`);
          return;
        }

        if (filter.type === 'boolean') {
          clauses.push(`${quoteIdentifier(filter.column)} = ${value ? 'TRUE' : 'FALSE'}`);
          return;
        }

        clauses.push(`${quoteIdentifier(filter.column)} ILIKE '%${escapeLike(value)}%' ESCAPE '\\'`);
      });
    }

    return clauses.length > 0 ? ` WHERE ${clauses.join(' AND ')}` : '';
  }

  async findMany(filters = {}) {
    const whereClause = this.buildWhereClause(filters);
    const orderColumn = quoteIdentifier(this.config.defaultOrderBy || this.config.idField);
    const orderDirection = String(this.config.defaultOrderDir || 'asc').toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
    const take = Number.isInteger(filters.take) ? filters.take : DEFAULT_TAKE;
    const skip = Number.isInteger(filters.skip) ? filters.skip : 0;
    const sql = `SELECT * FROM ${quoteQualifiedName(this.config.schema, this.config.viewName)}${whereClause} ORDER BY ${orderColumn} ${orderDirection} LIMIT ${take} OFFSET ${skip}`;

    return this.prisma.$queryRawUnsafe(sql);
  }

  async findById(id) {
    const sql = `SELECT * FROM ${quoteQualifiedName(this.config.schema, this.config.viewName)} WHERE ${quoteIdentifier(this.config.idField)} = ${Number(
      id
    )} LIMIT 1`;

    const rows = await this.prisma.$queryRawUnsafe(sql);
    return rows[0] || null;
  }
}

const normalizeResponseData = (data, sanitizeOutput) => {
  if (typeof sanitizeOutput !== 'function') {
    return data;
  }

  if (Array.isArray(data)) {
    return data.map((entry) => sanitizeOutput(entry));
  }

  return sanitizeOutput(data);
};

const buildStandardModule = (config) => {
  const validation = config.validation;
  const mapper = config.mapper;
  const repository = new TableRepository(config.prisma, config);
  const viewRepository = config.view ? new ViewRepository(config.prisma, config.view) : null;

  const service = {
    list: async (query = {}) => {
      const filters = validation.validateListQuery(query);
      const data = viewRepository ? await viewRepository.findMany(filters) : await repository.findMany(filters);
      return normalizeResponseData(data, config.sanitizeOutput);
    },

    search: async (query = {}) => {
      const filters = validation.validateSearchQuery(query);
      const data = viewRepository ? await viewRepository.findMany(filters) : await repository.findMany(filters);
      return normalizeResponseData(data, config.sanitizeOutput);
    },

    getById: async (id) => {
      const normalizedId = validation.parseId(id);
      const data = viewRepository ? await viewRepository.findById(normalizedId) : await repository.findById(normalizedId);

      if (!data) {
        throw createError(`${config.entityLabel} introuvable.`, 404, 'NOT_FOUND');
      }

      return normalizeResponseData(data, config.sanitizeOutput);
    },

    create: async (payload, context = {}) => {
      if (config.readOnly) {
        throw createError(`Le module ${config.moduleName} est en lecture seule.`, 409, 'READ_ONLY_MODULE');
      }

      validation.validateCreatePayload(payload);
      let data = mapper.toCreatePayload(payload);

      if (typeof config.validateRelations === 'function') {
        await config.validateRelations(data, { operation: 'create', context });
      }

      if (typeof config.transformCreate === 'function') {
        data = await config.transformCreate(data, { payload, context });
      }

      const created = await repository.create(data);
      if (viewRepository && config.refreshFromReadSource !== false) {
        const refreshed = await viewRepository.findById(created[config.idField]);
        return normalizeResponseData(refreshed || created, config.sanitizeOutput);
      }

      return normalizeResponseData(created, config.sanitizeOutput);
    },

    update: async (id, payload, context = {}) => {
      if (config.readOnly) {
        throw createError(`Le module ${config.moduleName} est en lecture seule.`, 409, 'READ_ONLY_MODULE');
      }

      const normalizedId = validation.parseId(id);
      validation.validateUpdatePayload(payload);
      const existing = await repository.findById(normalizedId);

      if (!existing) {
        throw createError(`${config.entityLabel} introuvable.`, 404, 'NOT_FOUND');
      }

      let data = mapper.toUpdatePayload(payload);

      if (typeof config.validateRelations === 'function') {
        await config.validateRelations(data, { operation: 'update', existing, context });
      }

      if (typeof config.transformUpdate === 'function') {
        data = await config.transformUpdate(data, { payload, existing, context });
      }

      const updated = await repository.update(normalizedId, data);
      if (viewRepository && config.refreshFromReadSource !== false) {
        const refreshed = await viewRepository.findById(updated[config.idField]);
        return normalizeResponseData(refreshed || updated, config.sanitizeOutput);
      }

      return normalizeResponseData(updated, config.sanitizeOutput);
    },

    remove: async (id, context = {}) => {
      if (config.readOnly) {
        throw createError(`Le module ${config.moduleName} est en lecture seule.`, 409, 'READ_ONLY_MODULE');
      }

      const normalizedId = validation.parseId(id);
      const existing = await repository.findById(normalizedId);

      if (!existing) {
        throw createError(`${config.entityLabel} introuvable.`, 404, 'NOT_FOUND');
      }

      if (typeof config.beforeDelete === 'function') {
        await config.beforeDelete(existing, { context });
      }

      const deleted = config.softDeleteField ? await repository.softDelete(normalizedId) : await repository.delete(normalizedId);
      if (viewRepository && config.refreshFromReadSource !== false) {
        const refreshed = await viewRepository.findById(existing[config.idField]);
        return normalizeResponseData(refreshed || deleted, config.sanitizeOutput);
      }

      return normalizeResponseData(deleted, config.sanitizeOutput);
    },
  };

  const normalizePrismaError = (error) => {
    if (error?.code === 'P2002') {
      return {
        statusCode: 409,
        message: 'Conflit d unicite detecte.',
        error: {
          code: 'UNIQUE_CONSTRAINT',
          details: error.meta || null,
        },
      };
    }

    if (error?.code === 'P2003') {
      return {
        statusCode: 409,
        message: 'Contrainte relationnelle detectee.',
        error: {
          code: 'RELATION_CONSTRAINT',
          details: error.meta || null,
        },
      };
    }

    if (error?.code === 'P2025') {
      return {
        statusCode: 404,
        message: `${config.entityLabel} introuvable.`,
        error: {
          code: 'NOT_FOUND',
          details: error.meta || null,
        },
      };
    }

    return {
      statusCode: error.statusCode || 500,
      message: error.message || 'Une erreur est survenue.',
      error: {
        code: error.code || 'INTERNAL_ERROR',
        details: error.details || null,
      },
    };
  };

  const sendSuccess = (res, statusCode, message, data) =>
    res.status(statusCode).json({
      success: true,
      message,
      data,
      error: null,
    });

  const sendError = (res, error) => {
    const normalized = normalizePrismaError(error);
    return res.status(normalized.statusCode).json({
      success: false,
      message: normalized.message,
      data: null,
      error: normalized.error,
    });
  };

  const controller = {
    list: async (req, res) => {
      try {
        const data = await service.list(req.query);
        return sendSuccess(res, 200, `${config.entityLabelPlural} recuperes avec succes.`, data);
      } catch (error) {
        return sendError(res, error);
      }
    },
    search: async (req, res) => {
      try {
        const data = await service.search(req.query);
        return sendSuccess(res, 200, `Recherche des ${config.entityLabelPluralLower} effectuee avec succes.`, data);
      } catch (error) {
        return sendError(res, error);
      }
    },
    getById: async (req, res) => {
      try {
        const data = await service.getById(req.params.id);
        return sendSuccess(res, 200, `${config.entityLabel} recupere avec succes.`, data);
      } catch (error) {
        return sendError(res, error);
      }
    },
  };

  if (!config.readOnly) {
    controller.create = async (req, res) => {
      try {
        const data = await service.create(req.body, { req });
        return sendSuccess(res, 201, `${config.entityLabel} cree avec succes.`, data);
      } catch (error) {
        return sendError(res, error);
      }
    };

    controller.update = async (req, res) => {
      try {
        const data = await service.update(req.params.id, req.body, { req });
        return sendSuccess(res, 200, `${config.entityLabel} mis a jour avec succes.`, data);
      } catch (error) {
        return sendError(res, error);
      }
    };

    controller.remove = async (req, res) => {
      try {
        const data = await service.remove(req.params.id, { req });
        const message = config.softDeleteField
          ? `${config.entityLabel} desactive avec succes.`
          : `${config.entityLabel} supprime avec succes.`;
        return sendSuccess(res, 200, message, data);
      } catch (error) {
        return sendError(res, error);
      }
    };
  }

  const router = express.Router();
  router.get('/search', controller.search);
  router.get('/:id', controller.getById);
  router.get('/', controller.list);

  if (!config.readOnly) {
    router.post('/', controller.create);
    router.put('/:id', controller.update);
    router.delete('/:id', controller.remove);
  }

  return {
    router,
    controller,
    service,
    repository,
    viewRepository,
    validation,
    mapper,
  };
};

module.exports = {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
  normalizeBoolean,
  normalizeDate,
  normalizeDecimal,
  normalizeInteger,
  normalizeNullableString,
  normalizeString,
  parseListQuery,
  parsePositiveInt,
  quoteIdentifier,
  quoteQualifiedName,
  validateEmail,
};
