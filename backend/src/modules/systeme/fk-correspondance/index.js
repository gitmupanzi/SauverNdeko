const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ModuleName: { type: 'string', requiredOnCreate: true },
  SchemaName: { type: 'string', requiredOnCreate: true },
  ViewName: { type: 'string', nullable: true },
  SourceKey: { type: 'string', requiredOnCreate: true },
  FieldName: { type: 'string', requiredOnCreate: true },
  FieldLabel: { type: 'string', nullable: true },
  MappingType: { type: 'string', requiredOnCreate: true },
  ReferenceSchemaName: { type: 'string', nullable: true },
  ReferenceObjectName: { type: 'string', nullable: true },
  ReferenceFieldName: { type: 'string', nullable: true },
  TargetCategoryIdFk: { type: 'int', nullable: true },
  MappingValue: { type: 'string', requiredOnCreate: true },
  IsDefaultMapping: { type: 'boolean' },
  ValideFkCorrespondance: { type: 'boolean' },
  SettingScope: { type: 'string', requiredOnCreate: true },
  ScopeValue: { type: 'string', nullable: true },
  DisplayOrder: { type: 'int' },
  UpdatedByUserFk: { type: 'int', nullable: true },
  ObsFkCorrespondance: { type: 'string', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'fk-correspondance' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    MappingType: 'generic_category',
    SettingScope: 'global',
    DisplayOrder: 0,
    IsDefaultMapping: false,
    ValideFkCorrespondance: true,
  },
});

const ensureRelations = async (data) => {
  if (data.TargetCategoryIdFk) {
    const categorie = await prisma.t_CategorieGenerique.findUnique({
      where: { ID_CategorieGenerique: data.TargetCategoryIdFk },
      select: { ID_CategorieGenerique: true },
    });
    if (!categorie) {
      throw createError('Categorie de correspondance introuvable.', 404, 'RELATION_NOT_FOUND', {
        field: 'TargetCategoryIdFk',
      });
    }
  }

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
  moduleName: 'systeme/fk-correspondance',
  modelName: 'T_Fk_Correspondance',
  delegateName: 't_Fk_Correspondance',
  idField: 'IdFkCorrespondance',
  entityLabel: 'Fk correspondance',
  entityLabelPlural: 'Fk correspondances',
  entityLabelPluralLower: 'fk correspondances',
  softDeleteField: 'ValideFkCorrespondance',
  validation,
  mapper,
  view: {
    schema: 'systeme',
    viewName: 'V_Fk_Correspondance_Detail',
    idField: 'IdFkCorrespondance',
    searchColumns: ['ModuleName', 'SchemaName', 'ViewName', 'FieldName', 'FieldLabel', 'MappingValue'],
    defaultOrderBy: 'IdFkCorrespondance',
    defaultOrderDir: 'desc',
    activeField: 'ValideFkCorrespondance',
  },
  validateRelations: ensureRelations,
});
