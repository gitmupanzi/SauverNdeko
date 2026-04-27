const { Prisma } = require('../generated/prisma');
const { toDelegateName } = require('./prismaMetadata');

const REQUIRED_FIELDS = ['IdUser', 'EmailUser', 'MotdepasseUser'];

const userEntitySelect = {
  IdEntite: true,
  NomEntite: true,
  EmailEntite: true,
  PhoneEntite: true,
  AdresseEntite: true,
};

const userRoleSelect = {
  ID_Generique: true,
  NomGenerique: true,
  AbrGenerique: true,
};

const userProfileSelect = {
  IdUser: true,
  NomUser: true,
  PrenomUser: true,
  EmailUser: true,
  PhoneUser: true,
  SexeUser: true,
  ValideUser: true,
  IdRoleFk: true,
  IdEntiteFk: true,
  DatecreationUser: true,
  DateModificationUser: true,
  UrlPhoto: true,
  Is_staff: true,
  Is_Admin: true,
  T_Entite: {
    select: userEntitySelect,
  },
  T_Generique: {
    select: userRoleSelect,
  },
};

const userAuthSelect = {
  ...userProfileSelect,
  MotdepasseUser: true,
};

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

const sanitizeUser = (user) => {
  const canAccessAdmin =
    Boolean(user.Is_Admin) ||
    Boolean(user.Is_staff) ||
    ['admin', 'administrateur'].includes(String(user.T_Generique?.NomGenerique || '').toLowerCase());

  return {
  IdUser: user.IdUser,
  NomUser: user.NomUser,
  PrenomUser: user.PrenomUser,
  EmailUser: user.EmailUser,
  PhoneUser: user.PhoneUser,
  SexeUser: user.SexeUser,
  ValideUser: user.ValideUser,
  IdRoleFk: user.IdRoleFk,
  IdEntiteFk: user.IdEntiteFk,
  DatecreationUser: user.DatecreationUser,
  DateModificationUser: user.DateModificationUser,
  UrlPhoto: user.UrlPhoto,
  role: user.T_Generique
    ? {
        id: user.T_Generique.ID_Generique,
        name: user.T_Generique.NomGenerique,
        abbreviation: user.T_Generique.AbrGenerique,
      }
    : null,
  entite: user.T_Entite
    ? {
        IdEntite: user.T_Entite.IdEntite,
        NomEntite: user.T_Entite.NomEntite,
        EmailEntite: user.T_Entite.EmailEntite,
        PhoneEntite: user.T_Entite.PhoneEntite,
        AdresseEntite: user.T_Entite.AdresseEntite,
      }
    : null,
  permissions: {
    canAccessAdmin,
  },
  };
};

module.exports = {
  getUserModel,
  sanitizeUser,
  userAuthSelect,
  userProfileSelect,
};
