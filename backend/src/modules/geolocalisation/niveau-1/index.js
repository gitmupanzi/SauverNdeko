const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ID_Niveau_0_Fk: { type: 'int', nullable: true },
  ID_Niveau_1_Old_Fk: { type: 'int', nullable: true },
  NomNiveau_1: { type: 'string', requiredOnCreate: true },
  Alt1_Niveau_1: { type: 'string', nullable: true },
  Alt2_Niveau_1: { type: 'string', nullable: true },
  AbreNiveau_1: { type: 'string', nullable: true },
  CodeSNIS: { type: 'string', nullable: true },
  CodeNiveau_1: { type: 'string', nullable: true },
  PopulationNiveau_1: { type: 'decimal', nullable: true, min: 0 },
  geometryNiveau_1: { type: 'string', nullable: true },
  surfaceNiveau_1: { type: 'string', nullable: true },
  timezoneNiveau_1: { type: 'string', nullable: true },
  wikidataNiveau_1: { type: 'string', nullable: true },
  EtenduNiveau_1: { type: 'string', nullable: true },
  ObsNiveau_1: { type: 'string', nullable: true },
  FusionNiveau_1: { type: 'boolean' },
  VisibleNiveau_1: { type: 'boolean' },
  VisibleNiveau_5: { type: 'boolean' },
  LatitudeNiveau_1: { type: 'decimal', nullable: true },
  LongitudeNiveau_1: { type: 'decimal', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-1' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    VisibleNiveau_1: true,
    VisibleNiveau_5: true,
  },
});

const ensureRelations = async (data) => {
  if (data.ID_Niveau_0_Fk) {
    const parent = await prisma.t_Niveau_0.findUnique({ where: { ID_Niveau_0: data.ID_Niveau_0_Fk }, select: { ID_Niveau_0: true } });
    if (!parent) {
      throw createError('Niveau 0 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_0_Fk' });
    }
  }

  if (data.ID_Niveau_1_Old_Fk) {
    const legacy = await prisma.t_Niveau_1_Old.findUnique({
      where: { ID_Niveau_1_Old: data.ID_Niveau_1_Old_Fk },
      select: { ID_Niveau_1_Old: true },
    });
    if (!legacy) {
      throw createError('Niveau 1 old introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_1_Old_Fk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-1',
  modelName: 'T_Niveau_1',
  delegateName: 't_Niveau_1',
  idField: 'ID_Niveau_1',
  entityLabel: 'Niveau 1',
  entityLabelPlural: 'Niveaux 1',
  entityLabelPluralLower: 'niveaux 1',
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_1',
    idField: 'ID_Niveau_1',
    searchColumns: ['NomNiveau_1', 'CodeNiveau_1', 'CodeSNIS', 'NomNiveau_0'],
    defaultOrderBy: 'ID_Niveau_1',
    defaultOrderDir: 'asc',
  },
  validateRelations: ensureRelations,
});
