const prisma = require('../../../../config/db');
const { buildBasicMapper, buildBasicValidation, buildStandardModule } = require('../../shared/module-kit');

const fieldRules = {
  NomNiveau_1_Old: { type: 'string', nullable: true },
  geometryNiveau_1_Old: { type: 'string', nullable: true },
  surfaceNiveau_1_Old: { type: 'string', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-1-old' });
const mapper = buildBasicMapper(fieldRules);

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-1-old',
  modelName: 'T_Niveau_1_Old',
  delegateName: 't_Niveau_1_Old',
  idField: 'ID_Niveau_1_Old',
  entityLabel: 'Niveau 1 old',
  entityLabelPlural: 'Niveaux 1 old',
  entityLabelPluralLower: 'niveaux 1 old',
  readOnly: true,
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_1_Old',
    idField: 'ID_Niveau_1_Old',
    searchColumns: ['NomNiveau_1_Old'],
    defaultOrderBy: 'ID_Niveau_1_Old',
    defaultOrderDir: 'asc',
  },
});
