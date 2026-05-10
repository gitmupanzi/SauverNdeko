const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ID_Niveau_3_Fk: { type: 'int', nullable: true },
  ID_TypeNiveau_4_Fk: { type: 'int', nullable: true },
  NomNiveau_4: { type: 'string', requiredOnCreate: true },
  AbreNiveau_4: { type: 'string', nullable: true },
  CodeNiveau_4: { type: 'string', nullable: true },
  surfaceNiveau_4: { type: 'string', nullable: true },
  geometryNiveau_4: { type: 'string', nullable: true },
  ID_DispoReseauNiveau_4: { type: 'int', nullable: true },
  ID_VoieAccesZsASFk: { type: 'int', nullable: true },
  ID_StatutNiveau_4: { type: 'int', nullable: true },
  ID_StatutDeploiementFk: { type: 'int', nullable: true },
  ObsNiveau_4: { type: 'string', nullable: true },
  SelectNiveau_4: { type: 'boolean' },
  LatitudeNiveau_4: { type: 'decimal', nullable: true },
  LongitudeNiveau_4: { type: 'decimal', nullable: true },
  AltitudeNiveau_4: { type: 'decimal', nullable: true },
  PopulationNiveau_4: { type: 'decimal', nullable: true, min: 0 },
  KmZoneSanteAS: { type: 'decimal', nullable: true, min: 0 },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-4' });
const mapper = buildBasicMapper(fieldRules);

const ensureRelations = async (data) => {
  if (data.ID_Niveau_3_Fk) {
    const parent = await prisma.t_Niveau_3.findUnique({ where: { ID_Niveau_3: data.ID_Niveau_3_Fk }, select: { ID_Niveau_3: true } });
    if (!parent) {
      throw createError('Niveau 3 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_3_Fk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-4',
  modelName: 'T_Niveau_4',
  delegateName: 't_Niveau_4',
  idField: 'ID_Niveau_4',
  entityLabel: 'Niveau 4',
  entityLabelPlural: 'Niveaux 4',
  entityLabelPluralLower: 'niveaux 4',
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_4',
    idField: 'ID_Niveau_4',
    searchColumns: ['NomNiveau_4', 'CodeNiveau_4', 'NomNiveau_3'],
    defaultOrderBy: 'ID_Niveau_4',
    defaultOrderDir: 'asc',
  },
  validateRelations: ensureRelations,
});
