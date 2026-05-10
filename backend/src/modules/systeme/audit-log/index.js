const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
} = require('../../shared/module-kit');

const fieldRules = {
  TableName: { type: 'string', nullable: true },
  Operation: { type: 'string', nullable: true },
  OldData: { type: 'json' },
  NewData: { type: 'json' },
  ChangedAt: { type: 'date', nullable: true },
  IdEntiteFk: { type: 'int', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'audit-log' });
const mapper = buildBasicMapper(fieldRules);

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/audit-log',
  modelName: 'T_Audit_Log',
  delegateName: 't_Audit_Log',
  idField: 'IdLog',
  entityLabel: 'Audit log',
  entityLabelPlural: 'Audit logs',
  entityLabelPluralLower: 'audit logs',
  readOnly: true,
  validation,
  mapper,
  view: {
    schema: 'systeme',
    viewName: 'V_Audit_log',
    idField: 'IdLog',
    searchColumns: ['TableName', 'Operation'],
    defaultOrderBy: 'IdLog',
    defaultOrderDir: 'desc',
  },
});
