const bcrypt = require('bcryptjs');
const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  NomUser: { type: 'string', requiredOnCreate: true },
  PrenomUser: { type: 'string', requiredOnCreate: true },
  EmailUser: { type: 'email', requiredOnCreate: true },
  MotdepasseUser: { type: 'string', requiredOnCreate: true },
  PhoneUser: { type: 'string', nullable: true },
  IdRoleFk: { type: 'int', nullable: true },
  ValideUser: { type: 'boolean' },
  SexeUser: { type: 'string', requiredOnCreate: true, enum: ['M', 'F'] },
  UrlPhoto: { type: 'string', nullable: true },
  IdEntiteFk: { type: 'int', nullable: true },
  Is_staff: { type: 'boolean' },
  Is_Admin: { type: 'boolean' },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'utilisateur' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    ValideUser: true,
    Is_staff: false,
    Is_Admin: false,
  },
});

const ensureRelations = async (data) => {
  if (data.IdEntiteFk) {
    const entite = await prisma.t_Entite.findUnique({ where: { IdEntite: data.IdEntiteFk }, select: { IdEntite: true } });
    if (!entite) {
      throw createError('Entite introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdEntiteFk' });
    }
  }

  if (data.IdRoleFk) {
    const role = await prisma.t_Generique.findUnique({
      where: { ID_Generique: data.IdRoleFk },
      select: { ID_Generique: true },
    });
    if (!role) {
      throw createError('Role introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdRoleFk' });
    }
  }
};

const moduleInstance = buildStandardModule({
  prisma,
  moduleName: 'systeme/utilisateur',
  modelName: 'T_Utilisateurs',
  delegateName: 't_Utilisateurs',
  idField: 'IdUser',
  entityLabel: 'Utilisateur',
  entityLabelPlural: 'Utilisateurs',
  entityLabelPluralLower: 'utilisateurs',
  softDeleteField: 'ValideUser',
  validation,
  mapper,
  tableSearchFields: ['NomUser', 'PrenomUser', 'EmailUser', 'PhoneUser'],
  view: {
    schema: 'systeme',
    viewName: 'V_User_profil',
    idField: 'IdUser',
    searchColumns: ['NomUser', 'PrenomUser', 'EmailUser', 'PhoneUser', 'NomComplet'],
    defaultOrderBy: 'IdUser',
    defaultOrderDir: 'desc',
    activeField: 'ValideUser',
  },
  sanitizeOutput: (row) => {
    if (!row || typeof row !== 'object') {
      return row;
    }

    const { MotdepasseUser, ...safeRow } = row;
    return safeRow;
  },
  validateRelations: ensureRelations,
  transformCreate: async (data) => ({
    ...data,
    MotdepasseUser: await bcrypt.hash(data.MotdepasseUser, 10),
  }),
  transformUpdate: async (data) => {
    const nextData = { ...data, DateModificationUser: new Date() };

    if (typeof data.MotdepasseUser === 'string' && data.MotdepasseUser.trim()) {
      nextData.MotdepasseUser = await bcrypt.hash(data.MotdepasseUser, 10);
    }

    return nextData;
  },
});

module.exports = moduleInstance;
