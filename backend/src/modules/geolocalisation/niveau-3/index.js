const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ID_Niveau_2_FK: { type: 'int', nullable: true },
  ID_TypeNiveau_2_Fk: { type: 'int', nullable: true },
  NomNiveau_3: { type: 'string', requiredOnCreate: true },
  Alt_Niveau_3: { type: 'string', nullable: true },
  surfaceNiveau_3: { type: 'string', nullable: true },
  geometryNiveau_3: { type: 'string', nullable: true },
  AbreNiveau_3: { type: 'string', nullable: true },
  CodeNiveau_3: { type: 'string', nullable: true },
  PopulationNiveau_3: { type: 'decimal', nullable: true, min: 0 },
  EtenduNiveau_3: { type: 'string', nullable: true },
  ObsNiveau_3: { type: 'string', nullable: true },
  ID_StatutNiveau_3_Fk: { type: 'int', nullable: true },
  ID_StatutDeploieFk: { type: 'int', nullable: true },
  KmAntenneBCZS: { type: 'decimal', nullable: true, min: 0 },
  ID_VoieAccesANTBCZFk: { type: 'int', nullable: true },
  KmDPSBCZS: { type: 'decimal', nullable: true, min: 0 },
  ID_VoieAccesDPSBCZFk: { type: 'int', nullable: true },
  SelectNiveau_3: { type: 'boolean' },
  LatitudeNiveau_3: { type: 'decimal', nullable: true },
  LongitudeNiveau_3: { type: 'decimal', nullable: true },
  AltitudeNiveau_3: { type: 'decimal', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-3' });
const mapper = buildBasicMapper(fieldRules);

const ensureRelations = async (data) => {
  if (data.ID_Niveau_2_FK) {
    const parent = await prisma.t_Niveau_2.findUnique({ where: { ID_Niveau_2: data.ID_Niveau_2_FK }, select: { ID_Niveau_2: true } });
    if (!parent) {
      throw createError('Niveau 2 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_2_FK' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-3',
  modelName: 'T_Niveau_3',
  delegateName: 't_Niveau_3',
  idField: 'ID_Niveau_3',
  entityLabel: 'Niveau 3',
  entityLabelPlural: 'Niveaux 3',
  entityLabelPluralLower: 'niveaux 3',
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_3',
    idField: 'ID_Niveau_3',
    searchColumns: ['NomNiveau_3', 'CodeNiveau_3', 'NomNiveau_2'],
    defaultOrderBy: 'ID_Niveau_3',
    defaultOrderDir: 'asc',
  },
  validateRelations: ensureRelations,
});
