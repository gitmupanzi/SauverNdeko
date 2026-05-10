const prisma = require('../../../../config/db');
const { buildBasicMapper, buildBasicValidation, buildStandardModule } = require('../../shared/module-kit');

const fieldRules = {
  NomNiveau_0: { type: 'string', requiredOnCreate: true },
  CodeNiveau_0: { type: 'string', nullable: true },
  geometryNiveau_0: { type: 'string', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-0' });
const mapper = buildBasicMapper(fieldRules);

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-0',
  modelName: 'T_Niveau_0',
  delegateName: 't_Niveau_0',
  idField: 'ID_Niveau_0',
  entityLabel: 'Niveau 0',
  entityLabelPlural: 'Niveaux 0',
  entityLabelPluralLower: 'niveaux 0',
  validation,
  mapper,
  tableSearchFields: ['NomNiveau_0', 'CodeNiveau_0'],
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_0',
    idField: 'ID_Niveau_0',
    searchColumns: ['NomNiveau_0', 'CodeNiveau_0'],
    defaultOrderBy: 'ID_Niveau_0',
    defaultOrderDir: 'asc',
  },
});
