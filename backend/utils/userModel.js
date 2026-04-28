const { Prisma } = require('../generated/prisma');
const { toDelegateName } = require('./prismaMetadata');

const REQUIRED_FIELDS = ['IdUser', 'EmailUser', 'MotdepasseUser'];

const userEntitySelect = {
  IdEntite: true,
  NomEntite: true,
  EmailEntite: true,
  PhoneEntite: true,
  AdresseEntite: true,
  T_Entite_Localisation: {
    select: {
      IdEntiteLocalisation: true,
      IdNiveau_3_Fk: true,
      IdNiveau_4_Fk: true,
      IdNiveau_5_Fk: true,
      T_Niveau_3: {
        select: {
          ID_Niveau_3: true,
          NomNiveau_3: true,
          T_Niveau_2: {
            select: {
              ID_Niveau_2: true,
              NomNiveau_2: true,
              T_Niveau_1: {
                select: {
                  ID_Niveau_1: true,
                  NomNiveau_1: true,
                  T_Niveau_0: {
                    select: {
                      ID_Niveau_0: true,
                      NomNiveau_0: true,
                      CodeNiveau_0: true,
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
    take: 1,
    orderBy: {
      IdEntiteLocalisation: 'asc',
    },
  },
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
  const entityLocation = Array.isArray(user.T_Entite?.T_Entite_Localisation)
    ? user.T_Entite.T_Entite_Localisation[0] || null
    : null;
  const niveau0 = entityLocation?.T_Niveau_3?.T_Niveau_2?.T_Niveau_1?.T_Niveau_0 || null;

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
        localisation:
          entityLocation
            ? {
                IdEntiteLocalisation: entityLocation.IdEntiteLocalisation,
                IdNiveau_3_Fk: entityLocation.IdNiveau_3_Fk,
                IdNiveau_4_Fk: entityLocation.IdNiveau_4_Fk,
                IdNiveau_5_Fk: entityLocation.IdNiveau_5_Fk,
                country: niveau0
                  ? {
                      id: niveau0.ID_Niveau_0,
                      name: niveau0.NomNiveau_0,
                      code: niveau0.CodeNiveau_0,
                    }
                  : null,
              }
            : null,
      }
    : null,
  scopeContext: {
    entity: user.T_Entite
      ? {
          id: user.T_Entite.IdEntite,
          name: user.T_Entite.NomEntite,
        }
      : null,
    country: niveau0
      ? {
          id: niveau0.ID_Niveau_0,
          name: niveau0.NomNiveau_0,
          code: niveau0.CodeNiveau_0,
        }
      : null,
  },
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
