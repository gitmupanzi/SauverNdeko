const { Prisma } = require('../generated/prisma');
const { toDelegateName } = require('./prismaMetadata');

const REQUIRED_FIELDS = ['IdUser', 'EmailUser', 'MotdepasseUser'];

const getUserModel = (prisma) => {
  const model = Prisma.dmmf.datamodel.models.find((item) =>
    REQUIRED_FIELDS.every((fieldName) => item.fields.some((field) => field.name === fieldName))
  );

  if (!model) {
    const error = new Error("Impossible d'identifier le modèle utilisateur dans Prisma.");
    error.statusCode = 500;
    throw error;
  }

  const delegateName = toDelegateName(model.name);
  const delegate = prisma[delegateName];

  if (!delegate) {
    const error = new Error(`Delegate Prisma introuvable pour le modèle utilisateur "${model.name}".`);
    error.statusCode = 500;
    throw error;
  }

  return {
    model,
    delegate,
    delegateName,
  };
};

const sanitizeUser = (user) => ({
  IdUser: user.IdUser,
  NomUser: user.NomUser,
  PrenomUser: user.PrenomUser,
  EmailUser: user.EmailUser,
  PhoneUser: user.PhoneUser,
  SexeUser: user.SexeUser,
  ValideUser: user.ValideUser,
  IdRoleFk: user.IdRoleFk,
  IdEntiteFk: user.IdEntiteFk,
  Is_staff: user.Is_staff,
  Is_Admin: user.Is_Admin,
  DatecreationUser: user.DatecreationUser,
  DateModificationUser: user.DateModificationUser,
  UrlPhoto: user.UrlPhoto,
});

module.exports = {
  getUserModel,
  sanitizeUser,
};
