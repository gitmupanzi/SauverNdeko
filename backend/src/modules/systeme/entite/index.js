const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  NomEntite: { type: 'string', requiredOnCreate: true },
  PhoneEntite: { type: 'string', nullable: true },
  EmailEntite: { type: 'email', requiredOnCreate: true },
  AdresseEntite: { type: 'string', nullable: true },
  IdTypeEntiteFk: { type: 'int', nullable: true },
  ValideEntite: { type: 'boolean' },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'entite' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    ValideEntite: true,
  },
});

const ensureRelations = async (data) => {
  if (data.IdTypeEntiteFk) {
    const typeEntite = await prisma.t_Generique.findUnique({
      where: { ID_Generique: data.IdTypeEntiteFk },
      select: { ID_Generique: true },
    });

    if (!typeEntite) {
      throw createError("Type d'entite introuvable.", 404, 'RELATION_NOT_FOUND', { field: 'IdTypeEntiteFk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/entite',
  modelName: 'T_Entite',
  delegateName: 't_Entite',
  idField: 'IdEntite',
  entityLabel: 'Entite',
  entityLabelPlural: 'Entites',
  entityLabelPluralLower: 'entites',
  softDeleteField: 'ValideEntite',
  validation,
  mapper,
  tableSearchFields: ['NomEntite', 'EmailEntite', 'PhoneEntite', 'AdresseEntite'],
  validateRelations: ensureRelations,
});
