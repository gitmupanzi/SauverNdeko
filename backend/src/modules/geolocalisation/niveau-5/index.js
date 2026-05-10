const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  ID_Niveau_4_Fk: { type: 'int', nullable: true },
  ID_Niveau_3_Fk: { type: 'int', nullable: true },
  ID_TypeNiveau_5_Fk: { type: 'int', nullable: true },
  NomNiveau_5: { type: 'string', requiredOnCreate: true },
  AbreNiveau_5: { type: 'string', nullable: true },
  CodeNiveau_5: { type: 'string', nullable: true },
  PopulationNiveau_5: { type: 'decimal', nullable: true, min: 0 },
  surfaceNiveau_5: { type: 'string', nullable: true },
  geometryNiveau_5: { type: 'string', nullable: true },
  ID_DispoReseauNiveau_5: { type: 'int', nullable: true },
  ID_VoieAccesZsSiteFk: { type: 'int', nullable: true },
  ID_StatutNiveau_5: { type: 'int', nullable: true },
  ID_StatutDeploiementFk: { type: 'int', nullable: true },
  ObsNiveau_5: { type: 'string', nullable: true },
  SelectNiveau_5: { type: 'boolean' },
  ID_TypeToitFk: { type: 'int', nullable: true },
  KmZoneSanteNiveau_5: { type: 'decimal', nullable: true, min: 0 },
  LatitudeNiveau_5: { type: 'decimal', nullable: true },
  LongitudeNiveau_5: { type: 'decimal', nullable: true },
  AltitudeNiveau_5: { type: 'decimal', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'niveau-5' });
const mapper = buildBasicMapper(fieldRules);

const ensureRelations = async (data) => {
  if (data.ID_Niveau_4_Fk) {
    const parent = await prisma.t_Niveau_4.findUnique({ where: { ID_Niveau_4: data.ID_Niveau_4_Fk }, select: { ID_Niveau_4: true } });
    if (!parent) {
      throw createError('Niveau 4 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_4_Fk' });
    }
  }

  if (data.ID_Niveau_3_Fk) {
    const parentN3 = await prisma.t_Niveau_3.findUnique({ where: { ID_Niveau_3: data.ID_Niveau_3_Fk }, select: { ID_Niveau_3: true } });
    if (!parentN3) {
      throw createError('Niveau 3 parent introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'ID_Niveau_3_Fk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'geolocalisation/niveau-5',
  modelName: 'T_Niveau_5',
  delegateName: 't_Niveau_5',
  idField: 'ID_Niveau_5',
  entityLabel: 'Niveau 5',
  entityLabelPlural: 'Niveaux 5',
  entityLabelPluralLower: 'niveaux 5',
  validation,
  mapper,
  view: {
    schema: 'geolocalisation',
    viewName: 'V_Niveau_5',
    idField: 'ID_Niveau_5',
    searchColumns: ['NomNiveau_5', 'CodeNiveau_5', 'NomNiveau_4', 'NomNiveau_3'],
    defaultOrderBy: 'ID_Niveau_5',
    defaultOrderDir: 'asc',
  },
  validateRelations: ensureRelations,
});
