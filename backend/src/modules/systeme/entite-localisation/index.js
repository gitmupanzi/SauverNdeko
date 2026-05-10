const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  IdEntiteFk: { type: 'int', requiredOnCreate: true },
  IdNiveau_3_Fk: { type: 'int', nullable: true },
  IdNiveau_4_Fk: { type: 'int', nullable: true },
  IdNiveau_5_Fk: { type: 'int', nullable: true },
  Latitude: { type: 'decimal', nullable: true },
  Longitude: { type: 'decimal', nullable: true },
  AdresseDetaillee: { type: 'string', nullable: true },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'entite-localisation' });
const mapper = buildBasicMapper(fieldRules);

const ensureRelations = async (data) => {
  if (data.IdEntiteFk) {
    const entite = await prisma.t_Entite.findUnique({ where: { IdEntite: data.IdEntiteFk }, select: { IdEntite: true } });
    if (!entite) {
      throw createError('Entite introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdEntiteFk' });
    }
  }

  if (data.IdNiveau_3_Fk) {
    const n3 = await prisma.t_Niveau_3.findUnique({ where: { ID_Niveau_3: data.IdNiveau_3_Fk }, select: { ID_Niveau_3: true } });
    if (!n3) {
      throw createError('Niveau 3 introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdNiveau_3_Fk' });
    }
  }

  if (data.IdNiveau_4_Fk) {
    const n4 = await prisma.t_Niveau_4.findUnique({ where: { ID_Niveau_4: data.IdNiveau_4_Fk }, select: { ID_Niveau_4: true } });
    if (!n4) {
      throw createError('Niveau 4 introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdNiveau_4_Fk' });
    }
  }

  if (data.IdNiveau_5_Fk) {
    const n5 = await prisma.t_Niveau_5.findUnique({ where: { ID_Niveau_5: data.IdNiveau_5_Fk }, select: { ID_Niveau_5: true } });
    if (!n5) {
      throw createError('Niveau 5 introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdNiveau_5_Fk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/entite-localisation',
  modelName: 'T_Entite_Localisation',
  delegateName: 't_Entite_Localisation',
  idField: 'IdEntiteLocalisation',
  entityLabel: 'Entite localisation',
  entityLabelPlural: 'Entite localisations',
  entityLabelPluralLower: 'entite localisations',
  validation,
  mapper,
  view: {
    schema: 'systeme',
    viewName: 'V_Entite_Localisation_Detail',
    idField: 'IdEntiteLocalisation',
    searchColumns: ['AdresseDetaillee', 'NomEntite', 'NomNiveau_3', 'NomNiveau_4', 'NomNiveau_5'],
    defaultOrderBy: 'IdEntiteLocalisation',
    defaultOrderDir: 'desc',
  },
  validateRelations: ensureRelations,
});
