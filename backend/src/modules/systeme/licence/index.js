const prisma = require('../../../../config/db');
const {
  buildBasicMapper,
  buildBasicValidation,
  buildStandardModule,
  createError,
} = require('../../shared/module-kit');

const fieldRules = {
  IdLicence: { type: 'int', requiredOnCreate: true },
  IdEntiteFk: { type: 'int', requiredOnCreate: true },
  CleLicence: { type: 'string', nullable: true },
  DateDebut: { type: 'date', nullable: true },
  DateFin: { type: 'date', requiredOnCreate: true },
  IdStatutLicenceFk: { type: 'int', requiredOnCreate: true },
  ValideLicence: { type: 'boolean' },
  ExpireeLicence: { type: 'boolean' },
};

const validation = buildBasicValidation(fieldRules, { idLabel: 'licence' });
const mapper = buildBasicMapper(fieldRules, {
  createDefaults: {
    ValideLicence: true,
    ExpireeLicence: false,
  },
});

const ensureRelations = async (data) => {
  if (data.IdEntiteFk) {
    const entite = await prisma.t_Entite.findUnique({ where: { IdEntite: data.IdEntiteFk }, select: { IdEntite: true } });
    if (!entite) {
      throw createError('Entite introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdEntiteFk' });
    }
  }

  if (data.IdStatutLicenceFk) {
    const statut = await prisma.t_Generique.findUnique({
      where: { ID_Generique: data.IdStatutLicenceFk },
      select: { ID_Generique: true },
    });
    if (!statut) {
      throw createError('Statut licence introuvable.', 404, 'RELATION_NOT_FOUND', { field: 'IdStatutLicenceFk' });
    }
  }
};

module.exports = buildStandardModule({
  prisma,
  moduleName: 'systeme/licence',
  modelName: 'T_Licence',
  delegateName: 't_Licence',
  idField: 'IdLicence',
  entityLabel: 'Licence',
  entityLabelPlural: 'Licences',
  entityLabelPluralLower: 'licences',
  softDeleteField: 'ValideLicence',
  validation,
  mapper,
  tableSearchFields: ['CleLicence'],
  view: {
    schema: 'systeme',
    viewName: 'V_Licence_active',
    idField: 'IdLicence',
    searchColumns: ['CleLicence', 'NomEntite', 'StatutLicence'],
    defaultOrderBy: 'IdLicence',
    defaultOrderDir: 'desc',
    activeField: 'ValideLicence',
  },
  validateRelations: ensureRelations,
});
