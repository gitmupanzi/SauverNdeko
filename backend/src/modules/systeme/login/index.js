const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
} = require('../../shared/module-kit');

const fieldRules = {
  IdUserFk: { type: 'int', requiredOnCreate: true },
  IdTypeLoginFk: { type: 'int', requiredOnCreate: true },
  DateLogin: { type: 'date', nullable: true },
  IdEntiteFk: { type: 'int', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'login' });
const mapper = buildBasicMapper(fieldRules);

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/login',
  modelName: 'T_Login',
  delegateName: 't_Login',
  idField: 'IdLogin',
  entityLabel: 'Login',
  entityLabelPlural: 'Logins',
  entityLabelPluralLower: 'logins',
  readOnly: true,
  validation,
  mapper,
  tableSearchFields: [],
  view: {
    schema: 'systeme',
    viewName: 'V_Login_history',
    idField: 'IdLogin',
    searchColumns: ['NomUser', 'PrenomUser', 'EmailUser', 'TypeLogin'],
    defaultOrderBy: 'IdLogin',
    defaultOrderDir: 'desc',
  },
});
