const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  SettingScope: { type: 'string', requiredOnCreate: true },
  ScopeValue: { type: 'string', nullable: true },
  SettingKey: { type: 'string', requiredOnCreate: true },
  SettingLabel: { type: 'string', nullable: true },
  SettingGroup: { type: 'string', nullable: true },
  SettingValue: { type: 'string', nullable: true },
  SettingValueJson: { type: 'json' },
  SettingType: { type: 'string', nullable: true },
  DisplayOrder: { type: 'int' },
  IsEditable: { type: 'boolean' },
  IsSystem: { type: 'boolean' },
  ValideSetting: { type: 'boolean' },
  UpdatedByUserFk: { type: 'int', nullable: true },
  ObsSetting: { type: 'string', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'admin-ui-setting' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    SettingScope: 'global',
    SettingGroup: 'general',
    SettingType: 'text',
    DisplayOrder: 0,
    IsEditable: true,
    IsSystem: false,
    ValideSetting: true,
  },
});

const ensureRelations = async (data) => {
  if (data.UpdatedByUserFk) {
    const user = await prisma.t_Utilisateurs.findUnique({ where: { IdUser: data.UpdatedByUserFk }, select: { IdUser: true } });
    if (!user) {
      throw createError('Utilisateur de mise a jour introuvable.', 404, 'RELATION_NOT_FOUND', {
        field: 'UpdatedByUserFk',
      });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/admin-ui-setting',
  modelName: 'T_Admin_UI_Setting',
  delegateName: 't_Admin_UI_Setting',
  idField: 'IdAdminUISetting',
  entityLabel: 'Admin ui setting',
  entityLabelPlural: 'Admin ui settings',
  entityLabelPluralLower: 'admin ui settings',
  softDeleteField: 'ValideSetting',
  validation,
  mapper,
  view: {
    schema: 'systeme',
    viewName: 'V_Admin_UI_Setting',
    idField: 'IdAdminUISetting',
    searchColumns: ['SettingKey', 'SettingLabel', 'SettingGroup', 'ScopeValue'],
    defaultOrderBy: 'IdAdminUISetting',
    defaultOrderDir: 'desc',
    activeField: 'ValideSetting',
  },
  validateRelations: ensureRelations,
});
