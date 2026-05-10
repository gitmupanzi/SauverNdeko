const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ID_Niveau_1_FK: { type: 'int', nullable: true },
  ID_TypeNiveau_2_Fk: { type: 'int', nullable: true },
  NomNiveau_2: { type: 'string', requiredOnCreate: true },
  Alt1_NomNiveau_2: { type: 'string', nullable: true },
  AbreNiveau_2: { type: 'string', nullable: true },
  CodeNiveau_2: { type: 'string', nullable: true },
  PopulationNiveau_2: { type: 'decimal', nullable: true, min: 0 },
  geometryNiveau_2: { type: 'string', nullable: true },
  surfaceNiveau_2: { type: 'string', nullable: true },
  EtenduNiveau_2: { type: 'string', nullable: true },
  ObsNiveau_2: { type: 'string', nullable: true },
  ID_StatutNiveau_2: { type: 'int', nullable: true },
  ID_StatusDeploiFk: { type: 'int', nullable: true },
  KmDPSANT: { type: 'decimal', nullable: true, min: 0 },
  ID_VoieAccesDPSANTFk: { type: 'int', nullable: true },
  SelectNiveau_2: { type: 'boolean' },
  LatitudeNiveau_2: { type: 'decimal', nullable: true },
  LongitudeNiveau_2: { type: 'decimal', nullable: true },
  AltitudeNiveau_2: { type: 'decimal', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-2' });
const mapper = buildBasicMapper(fieldRules);

const ensureRelations = async (data) => {
  if (data.ID_Niveau_1_FK) {
    const parent = await prisma.t_Niveau_1.findUnique({ where: { ID_Niveau_1: data.ID_Niveau_1_FK }, select: { ID_Niveau_1: true } });
    if (!parent) {
      throw createError('Niveau 1 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_1_FK' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-2',
  modelName: 'T_Niveau_2',
  delegateName: 't_Niveau_2',
  idField: 'ID_Niveau_2',
  entityLabel: 'Niveau 2',
  entityLabelPlural: 'Niveaux 2',
  entityLabelPluralLower: 'niveaux 2',
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_2',
    idField: 'ID_Niveau_2',
    searchColumns: ['NomNiveau_2', 'CodeNiveau_2', 'NomNiveau_1'],
    defaultOrderBy: 'ID_Niveau_2',
    defaultOrderDir: 'asc',
  },
  validateRelations: ensureRelations,
});
