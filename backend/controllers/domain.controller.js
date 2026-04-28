const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { recordAdminAuditLog } = require('../utils/adminAudit');

const DEFAULT_TAKE = 20;
const MAX_TAKE = 100;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const parseTake = (value) => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    return DEFAULT_TAKE;
  }

  return Math.min(parsed, MAX_TAKE);
};

const parseSkip = (value) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= 0 ? parsed : 0;
};

const parseId = (value, label = 'identifiant') => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const buildContains = (value) => {
  if (!value) {
    return undefined;
  }

  return {
    contains: value,
    mode: 'insensitive',
  };
};

const buildListMeta = (data, take, skip) => ({
  count: data.length,
  take,
  skip,
});

const normalizeOptionalString = (value) => {
  if (value == null) {
    return undefined;
  }

  return String(value).trim();
};

const ensureBoolean = (value, fallback = false) => (typeof value === 'boolean' ? value : fallback);

const ensureEmail = (value, label = 'email') => {
  if (!value || !EMAIL_REGEX.test(value)) {
    const error = new Error(`Adresse ${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return value;
};

const ensureUserSex = (value) => {
  if (!['M', 'F'].includes(value)) {
    const error = new Error('Le sexe doit etre "M" ou "F".');
    error.statusCode = 400;
    throw error;
  }

  return value;
};

const ensureDateValue = (value, label = 'date') => {
  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const ensurePositiveForeignKey = (value, label) => {
  if (value == null || value === '') {
    return null;
  }

  return parseId(value, label);
};

const includeUser = {
  T_Entite: {
    select: {
      IdEntite: true,
      NomEntite: true,
      EmailEntite: true,
    },
  },
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_Professionnel: {
    select: {
      IdProfessionnel: true,
      IdTypeProfessionnelFk: true,
      IdSpecialiteFk: true,
      ExperienceAns: true,
      ValideProfessionnel: true,
    },
  },
};

const includeEntity = {
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_Entite_Localisation: {
    select: {
      IdEntiteLocalisation: true,
      Latitude: true,
      Longitude: true,
      AdresseDetaillee: true,
      T_Niveau_3: {
        select: {
          ID_Niveau_3: true,
          NomNiveau_3: true,
        },
      },
      T_Niveau_4: {
        select: {
          ID_Niveau_4: true,
          NomNiveau_4: true,
        },
      },
      T_Niveau_5: {
        select: {
          ID_Niveau_5: true,
          NomNiveau_5: true,
        },
      },
    },
  },
};

const includeLicence = {
  T_Entite: {
    select: {
      IdEntite: true,
      NomEntite: true,
      EmailEntite: true,
      PhoneEntite: true,
    },
  },
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
};

const includeArticle = {
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
      IdEntiteFk: true,
      T_Entite: {
        select: {
          IdEntite: true,
          NomEntite: true,
          PhoneEntite: true,
          EmailEntite: true,
          AdresseEntite: true,
        },
      },
    },
  },
};

const includeProfessionnel = {
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
      PhoneUser: true,
      UrlPhoto: true,
      IdEntiteFk: true,
      T_Entite: {
        select: {
          IdEntite: true,
          NomEntite: true,
          PhoneEntite: true,
          EmailEntite: true,
          AdresseEntite: true,
        },
      },
    },
  },
  T_GeneriqueSpecialite: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_GeneriqueType: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_Professionnel_Entite: {
    include: {
      T_Entite: {
        select: {
          IdEntite: true,
          NomEntite: true,
          PhoneEntite: true,
          EmailEntite: true,
          AdresseEntite: true,
        },
      },
    },
  },
};

const includeRecherche = {
  T_Article: {
    select: {
      ID_Article: true,
      NomArticle: true,
      PVArticle: true,
    },
  },
  T_Entite: {
    select: {
      IdEntite: true,
      NomEntite: true,
      PhoneEntite: true,
      EmailEntite: true,
    },
  },
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
    },
  },
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
    },
  },
};

const includeCommande = {
  T_Utilisateurs: {
    select: {
      IdUser: true,
      NomUser: true,
      PrenomUser: true,
      EmailUser: true,
    },
  },
  T_CommandeDetail: {
    include: {
      T_Article: {
        select: {
          ID_Article: true,
          NomArticle: true,
          PUArticle: true,
          PVArticle: true,
        },
      },
    },
  },
  T_Mouvement: true,
};

const listUtilisateurs = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Utilisateurs.findMany({
    where: q
      ? {
          OR: [
            { NomUser: buildContains(q) },
            { PrenomUser: buildContains(q) },
            { EmailUser: buildContains(q) },
            { PhoneUser: buildContains(q) },
          ],
        }
      : undefined,
    include: includeUser,
    orderBy: [{ DatecreationUser: 'desc' }, { IdUser: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getUtilisateur = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant utilisateur");

  const data = await prisma.t_Utilisateurs.findUnique({
    where: { IdUser: id },
    include: {
      ...includeUser,
      T_Recherche: {
        take: 5,
        orderBy: { DateRecherche: 'desc' },
      },
      T_Commande: {
        take: 5,
        orderBy: { DateCmd: 'desc' },
      },
    },
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Utilisateur introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createUtilisateur = catchAsync(async (req, res) => {
  const NomUser = normalizeOptionalString(req.body.NomUser);
  const PrenomUser = normalizeOptionalString(req.body.PrenomUser);
  const EmailUser = normalizeOptionalString(req.body.EmailUser);
  const MotdepasseUser = typeof req.body.MotdepasseUser === 'string' ? req.body.MotdepasseUser : '';
  const SexeUser = normalizeOptionalString(req.body.SexeUser);
  const PhoneUser = normalizeOptionalString(req.body.PhoneUser);
  const UrlPhoto = normalizeOptionalString(req.body.UrlPhoto);
  const IdRoleFk = ensurePositiveForeignKey(req.body.IdRoleFk, 'Role');
  const IdEntiteFk = ensurePositiveForeignKey(req.body.IdEntiteFk, 'Entite');

  if (!NomUser || !PrenomUser || !EmailUser || !MotdepasseUser || !SexeUser) {
    return res.status(400).json({
      success: false,
      message: 'Nom, prenom, email, mot de passe et sexe sont obligatoires.',
    });
  }

  ensureEmail(EmailUser, 'email');
  ensureUserSex(SexeUser);

  const existingUser = await prisma.t_Utilisateurs.findUnique({
    where: { EmailUser },
  });

  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: 'Un utilisateur avec cet email existe deja.',
    });
  }

  if (PhoneUser) {
    const existingPhoneUser = await prisma.t_Utilisateurs.findFirst({
      where: { PhoneUser },
      select: { IdUser: true },
    });

    if (existingPhoneUser) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec ce numero de telephone existe deja.',
      });
    }
  }

  if (IdEntiteFk) {
    const entity = await prisma.t_Entite.findUnique({
      where: { IdEntite: IdEntiteFk },
      select: { IdEntite: true },
    });

    if (!entity) {
      return res.status(404).json({
        success: false,
        message: 'Entite introuvable.',
      });
    }
  }

  if (IdRoleFk) {
    const role = await prisma.t_Generique.findUnique({
      where: { ID_Generique: IdRoleFk },
      select: { ID_Generique: true },
    });

    if (!role) {
      return res.status(404).json({
        success: false,
        message: 'Role introuvable.',
      });
    }
  }

  const hashedPassword = await bcrypt.hash(MotdepasseUser, 10);

  const data = await prisma.t_Utilisateurs.create({
    data: {
      NomUser,
      PrenomUser,
      EmailUser,
      MotdepasseUser: hashedPassword,
      SexeUser,
      PhoneUser: PhoneUser || null,
      IdRoleFk,
      IdEntiteFk,
      ValideUser: ensureBoolean(req.body.ValideUser, true),
      UrlPhoto: UrlPhoto || null,
      Is_staff: ensureBoolean(req.body.Is_staff, false),
      Is_Admin: ensureBoolean(req.body.Is_Admin, false),
    },
    include: includeUser,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Utilisateurs',
    operation: 'CREATE',
    newData: data,
  });

  res.status(201).json({ success: true, data });
});

const updateUtilisateur = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant utilisateur");
  const existingUser = await prisma.t_Utilisateurs.findUnique({
    where: { IdUser: id },
  });

  if (!existingUser) {
    return res.status(404).json({
      success: false,
      message: 'Utilisateur introuvable.',
    });
  }

  const payload = {};
  const nextNomUser = normalizeOptionalString(req.body.NomUser);
  const nextPrenomUser = normalizeOptionalString(req.body.PrenomUser);
  const nextEmailUser = normalizeOptionalString(req.body.EmailUser);
  const nextPhoneUser = normalizeOptionalString(req.body.PhoneUser);
  const nextSexeUser = normalizeOptionalString(req.body.SexeUser);
  const nextUrlPhoto = normalizeOptionalString(req.body.UrlPhoto);

  if (nextNomUser !== undefined) {
    if (!nextNomUser) {
      return res.status(400).json({ success: false, message: 'Le nom est obligatoire.' });
    }

    payload.NomUser = nextNomUser;
  }

  if (nextPrenomUser !== undefined) {
    if (!nextPrenomUser) {
      return res.status(400).json({ success: false, message: 'Le prenom est obligatoire.' });
    }

    payload.PrenomUser = nextPrenomUser;
  }

  if (nextEmailUser !== undefined) {
    payload.EmailUser = ensureEmail(nextEmailUser, 'email');
  }

  if (nextPhoneUser !== undefined) {
    payload.PhoneUser = nextPhoneUser || null;
  }

  if (nextSexeUser !== undefined) {
    payload.SexeUser = ensureUserSex(nextSexeUser);
  }

  if (nextUrlPhoto !== undefined) {
    payload.UrlPhoto = nextUrlPhoto || null;
  }

  if (req.body.IdRoleFk !== undefined) {
    payload.IdRoleFk = ensurePositiveForeignKey(req.body.IdRoleFk, 'Role');
  }

  if (req.body.IdEntiteFk !== undefined) {
    payload.IdEntiteFk = ensurePositiveForeignKey(req.body.IdEntiteFk, 'Entite');
  }

  if (req.body.ValideUser !== undefined) {
    payload.ValideUser = ensureBoolean(req.body.ValideUser, existingUser.ValideUser !== false);
  }

  if (req.body.Is_staff !== undefined) {
    payload.Is_staff = ensureBoolean(req.body.Is_staff, Boolean(existingUser.Is_staff));
  }

  if (req.body.Is_Admin !== undefined) {
    payload.Is_Admin = ensureBoolean(req.body.Is_Admin, Boolean(existingUser.Is_Admin));
  }

  if (typeof req.body.MotdepasseUser === 'string' && req.body.MotdepasseUser.trim()) {
    payload.MotdepasseUser = await bcrypt.hash(req.body.MotdepasseUser, 10);
  }

  if (payload.EmailUser && payload.EmailUser !== existingUser.EmailUser) {
    const conflictingEmailUser = await prisma.t_Utilisateurs.findFirst({
      where: {
        IdUser: { not: id },
        EmailUser: payload.EmailUser,
      },
      select: { IdUser: true },
    });

    if (conflictingEmailUser) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec cet email existe deja.',
      });
    }
  }

  if (payload.PhoneUser && payload.PhoneUser !== existingUser.PhoneUser) {
    const conflictingPhoneUser = await prisma.t_Utilisateurs.findFirst({
      where: {
        IdUser: { not: id },
        PhoneUser: payload.PhoneUser,
      },
      select: { IdUser: true },
    });

    if (conflictingPhoneUser) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec ce numero de telephone existe deja.',
      });
    }
  }

  if (payload.IdEntiteFk) {
    const entity = await prisma.t_Entite.findUnique({
      where: { IdEntite: payload.IdEntiteFk },
      select: { IdEntite: true },
    });

    if (!entity) {
      return res.status(404).json({
        success: false,
        message: 'Entite introuvable.',
      });
    }
  }

  if (payload.IdRoleFk) {
    const role = await prisma.t_Generique.findUnique({
      where: { ID_Generique: payload.IdRoleFk },
      select: { ID_Generique: true },
    });

    if (!role) {
      return res.status(404).json({
        success: false,
        message: 'Role introuvable.',
      });
    }
  }

  payload.DateModificationUser = new Date();

  const data = await prisma.t_Utilisateurs.update({
    where: { IdUser: id },
    data: payload,
    include: includeUser,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Utilisateurs',
    operation: 'UPDATE',
    oldData: existingUser,
    newData: data,
  });

  res.json({ success: true, data });
});

const removeUtilisateur = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant utilisateur");

  const existingUser = await prisma.t_Utilisateurs.findUnique({
    where: { IdUser: id },
  });

  if (!existingUser) {
    return res.status(404).json({
      success: false,
      message: 'Utilisateur introuvable.',
    });
  }

  await prisma.t_Utilisateurs.delete({
    where: { IdUser: id },
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Utilisateurs',
    operation: 'DELETE',
    oldData: existingUser,
  });

  res.json({
    success: true,
    message: 'Utilisateur supprime.',
  });
});

const listEntites = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Entite.findMany({
    where: q
      ? {
          OR: [
            { NomEntite: buildContains(q) },
            { EmailEntite: buildContains(q) },
            { AdresseEntite: buildContains(q) },
            { PhoneEntite: buildContains(q) },
          ],
        }
      : undefined,
    include: includeEntity,
    orderBy: [{ DateCreationEntite: 'desc' }, { IdEntite: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getEntite = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant entite");

  const data = await prisma.t_Entite.findUnique({
    where: { IdEntite: id },
    include: {
      ...includeEntity,
      T_Utilisateurs: {
        select: {
          IdUser: true,
          NomUser: true,
          PrenomUser: true,
          EmailUser: true,
        },
      },
      T_Professionnel_Entite: {
        include: {
          T_Professionnel: {
            include: {
              T_Utilisateurs: {
                select: {
                  IdUser: true,
                  NomUser: true,
                  PrenomUser: true,
                },
              },
            },
          },
        },
      },
    },
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Entite introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createEntite = catchAsync(async (req, res) => {
  const NomEntite = normalizeOptionalString(req.body.NomEntite);
  const EmailEntite = normalizeOptionalString(req.body.EmailEntite);
  const PhoneEntite = normalizeOptionalString(req.body.PhoneEntite);
  const AdresseEntite = normalizeOptionalString(req.body.AdresseEntite);
  const IdTypeEntiteFk = ensurePositiveForeignKey(req.body.IdTypeEntiteFk, 'Type entite');

  if (!NomEntite || !EmailEntite) {
    return res.status(400).json({
      success: false,
      message: 'NomEntite et EmailEntite sont obligatoires.',
    });
  }

  ensureEmail(EmailEntite, "email d'entite");

  const existingEntity = await prisma.t_Entite.findUnique({
    where: { EmailEntite },
    select: { IdEntite: true },
  });

  if (existingEntity) {
    return res.status(409).json({
      success: false,
      message: 'Une entite avec cet email existe deja.',
    });
  }

  if (PhoneEntite) {
    const existingEntityPhone = await prisma.t_Entite.findFirst({
      where: { PhoneEntite },
      select: { IdEntite: true },
    });

    if (existingEntityPhone) {
      return res.status(409).json({
        success: false,
        message: 'Une entite avec ce telephone existe deja.',
      });
    }
  }

  const data = await prisma.t_Entite.create({
    data: {
      NomEntite,
      EmailEntite,
      PhoneEntite: PhoneEntite || null,
      AdresseEntite: AdresseEntite || null,
      IdTypeEntiteFk,
      ValideEntite: ensureBoolean(req.body.ValideEntite, true),
    },
    include: includeEntity,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Entite',
    operation: 'CREATE',
    newData: data,
  });

  res.status(201).json({ success: true, data });
});

const updateEntite = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant entite");
  const existingEntity = await prisma.t_Entite.findUnique({
    where: { IdEntite: id },
  });

  if (!existingEntity) {
    return res.status(404).json({
      success: false,
      message: 'Entite introuvable.',
    });
  }

  const payload = {};
  const nextNomEntite = normalizeOptionalString(req.body.NomEntite);
  const nextEmailEntite = normalizeOptionalString(req.body.EmailEntite);
  const nextPhoneEntite = normalizeOptionalString(req.body.PhoneEntite);
  const nextAdresseEntite = normalizeOptionalString(req.body.AdresseEntite);

  if (nextNomEntite !== undefined) {
    if (!nextNomEntite) {
      return res.status(400).json({ success: false, message: "Le nom d'entite est obligatoire." });
    }

    payload.NomEntite = nextNomEntite;
  }

  if (nextEmailEntite !== undefined) {
    payload.EmailEntite = ensureEmail(nextEmailEntite, "email d'entite");
  }

  if (nextPhoneEntite !== undefined) {
    payload.PhoneEntite = nextPhoneEntite || null;
  }

  if (nextAdresseEntite !== undefined) {
    payload.AdresseEntite = nextAdresseEntite || null;
  }

  if (req.body.IdTypeEntiteFk !== undefined) {
    payload.IdTypeEntiteFk = ensurePositiveForeignKey(req.body.IdTypeEntiteFk, 'Type entite');
  }

  if (req.body.ValideEntite !== undefined) {
    payload.ValideEntite = ensureBoolean(req.body.ValideEntite, existingEntity.ValideEntite !== false);
  }

  if (payload.EmailEntite && payload.EmailEntite !== existingEntity.EmailEntite) {
    const conflictingEntity = await prisma.t_Entite.findFirst({
      where: {
        IdEntite: { not: id },
        EmailEntite: payload.EmailEntite,
      },
      select: { IdEntite: true },
    });

    if (conflictingEntity) {
      return res.status(409).json({
        success: false,
        message: 'Une entite avec cet email existe deja.',
      });
    }
  }

  if (payload.PhoneEntite && payload.PhoneEntite !== existingEntity.PhoneEntite) {
    const conflictingEntityPhone = await prisma.t_Entite.findFirst({
      where: {
        IdEntite: { not: id },
        PhoneEntite: payload.PhoneEntite,
      },
      select: { IdEntite: true },
    });

    if (conflictingEntityPhone) {
      return res.status(409).json({
        success: false,
        message: 'Une entite avec ce telephone existe deja.',
      });
    }
  }

  const data = await prisma.t_Entite.update({
    where: { IdEntite: id },
    data: payload,
    include: includeEntity,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Entite',
    operation: 'UPDATE',
    oldData: existingEntity,
    newData: data,
  });

  res.json({ success: true, data });
});

const removeEntite = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant entite");

  const existingEntity = await prisma.t_Entite.findUnique({
    where: { IdEntite: id },
  });

  if (!existingEntity) {
    return res.status(404).json({
      success: false,
      message: 'Entite introuvable.',
    });
  }

  await prisma.t_Entite.delete({
    where: { IdEntite: id },
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Entite',
    operation: 'DELETE',
    oldData: existingEntity,
    idEntiteFk: existingEntity.IdEntite,
  });

  res.json({
    success: true,
    message: 'Entite supprimee.',
  });
});

const listLicences = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Licence.findMany({
    where: q
      ? {
          OR: [
            { T_Entite: { is: { NomEntite: buildContains(q) } } },
            { T_Generique: { is: { NomGenerique: buildContains(q) } } },
          ],
        }
      : undefined,
    include: includeLicence,
    orderBy: [{ DateFin: 'desc' }, { IdLicence: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getLicence = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, 'Identifiant licence');

  const data = await prisma.t_Licence.findUnique({
    where: { IdLicence: id },
    include: includeLicence,
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Licence introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createLicence = catchAsync(async (req, res) => {
  const IdLicence = parseId(req.body.IdLicence, 'Identifiant licence');
  const IdEntiteFk = parseId(req.body.IdEntiteFk, 'Entite');
  const IdStatutLicenceFk = parseId(req.body.IdStatutLicenceFk, 'Statut licence');
  const DateDebut = req.body.DateDebut ? ensureDateValue(req.body.DateDebut, 'Date de debut') : new Date();
  const DateFin = ensureDateValue(req.body.DateFin, 'Date de fin');

  if (DateFin <= DateDebut) {
    return res.status(400).json({
      success: false,
      message: 'La date de fin doit etre posterieure a la date de debut.',
    });
  }

  const [existingLicence, entite, statut] = await Promise.all([
    prisma.t_Licence.findUnique({
      where: { IdLicence },
      select: { IdLicence: true },
    }),
    prisma.t_Entite.findUnique({
      where: { IdEntite: IdEntiteFk },
      select: { IdEntite: true },
    }),
    prisma.t_Generique.findUnique({
      where: { ID_Generique: IdStatutLicenceFk },
      select: { ID_Generique: true },
    }),
  ]);

  if (existingLicence) {
    return res.status(409).json({
      success: false,
      message: 'Une licence avec cet identifiant existe deja.',
    });
  }

  if (!entite) {
    return res.status(404).json({
      success: false,
      message: 'Entite introuvable.',
    });
  }

  if (!statut) {
    return res.status(404).json({
      success: false,
      message: 'Statut de licence introuvable.',
    });
  }

  const data = await prisma.t_Licence.create({
    data: {
      IdLicence,
      IdEntiteFk,
      IdStatutLicenceFk,
      DateDebut,
      DateFin,
      ValideLicence: ensureBoolean(req.body.ValideLicence, true),
      ExpireeLicence: ensureBoolean(req.body.ExpireeLicence, false),
    },
    include: includeLicence,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Licence',
    operation: 'CREATE',
    newData: data,
    idEntiteFk: data.IdEntiteFk,
  });

  res.status(201).json({ success: true, data });
});

const updateLicence = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, 'Identifiant licence');
  const existingLicence = await prisma.t_Licence.findUnique({
    where: { IdLicence: id },
  });

  if (!existingLicence) {
    return res.status(404).json({
      success: false,
      message: 'Licence introuvable.',
    });
  }

  const payload = {};

  if (req.body.IdEntiteFk !== undefined) {
    payload.IdEntiteFk = parseId(req.body.IdEntiteFk, 'Entite');
  }

  if (req.body.IdStatutLicenceFk !== undefined) {
    payload.IdStatutLicenceFk = parseId(req.body.IdStatutLicenceFk, 'Statut licence');
  }

  if (req.body.DateDebut !== undefined) {
    payload.DateDebut = ensureDateValue(req.body.DateDebut, 'Date de debut');
  }

  if (req.body.DateFin !== undefined) {
    payload.DateFin = ensureDateValue(req.body.DateFin, 'Date de fin');
  }

  if (req.body.ValideLicence !== undefined) {
    payload.ValideLicence = ensureBoolean(req.body.ValideLicence, existingLicence.ValideLicence !== false);
  }

  if (req.body.ExpireeLicence !== undefined) {
    payload.ExpireeLicence = ensureBoolean(req.body.ExpireeLicence, Boolean(existingLicence.ExpireeLicence));
  }

  const nextDateDebut = payload.DateDebut || existingLicence.DateDebut;
  const nextDateFin = payload.DateFin || existingLicence.DateFin;

  if (nextDateFin <= nextDateDebut) {
    return res.status(400).json({
      success: false,
      message: 'La date de fin doit etre posterieure a la date de debut.',
    });
  }

  if (payload.IdEntiteFk) {
    const entite = await prisma.t_Entite.findUnique({
      where: { IdEntite: payload.IdEntiteFk },
      select: { IdEntite: true },
    });

    if (!entite) {
      return res.status(404).json({
        success: false,
        message: 'Entite introuvable.',
      });
    }
  }

  if (payload.IdStatutLicenceFk) {
    const statut = await prisma.t_Generique.findUnique({
      where: { ID_Generique: payload.IdStatutLicenceFk },
      select: { ID_Generique: true },
    });

    if (!statut) {
      return res.status(404).json({
        success: false,
        message: 'Statut de licence introuvable.',
      });
    }
  }

  const data = await prisma.t_Licence.update({
    where: { IdLicence: id },
    data: payload,
    include: includeLicence,
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Licence',
    operation: 'UPDATE',
    oldData: existingLicence,
    newData: data,
    idEntiteFk: data.IdEntiteFk,
  });

  res.json({ success: true, data });
});

const removeLicence = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, 'Identifiant licence');
  const existingLicence = await prisma.t_Licence.findUnique({
    where: { IdLicence: id },
  });

  if (!existingLicence) {
    return res.status(404).json({
      success: false,
      message: 'Licence introuvable.',
    });
  }

  await prisma.t_Licence.delete({
    where: { IdLicence: id },
  });

  await recordAdminAuditLog({
    tableName: 'systeme.T_Licence',
    operation: 'DELETE',
    oldData: existingLicence,
    idEntiteFk: existingLicence.IdEntiteFk,
  });

  res.json({
    success: true,
    message: 'Licence supprimee.',
  });
});

const listArticles = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();
  const activeOnly = req.query.active === 'true';

  const data = await prisma.t_Article.findMany({
    where: {
      ...(activeOnly ? { ValideArticle: true } : {}),
      ...(q
        ? {
            OR: [
              { NomArticle: buildContains(q) },
              { RefArticle: buildContains(q) },
              { CodeArticleInterne: buildContains(q) },
            ],
          }
        : {}),
    },
    include: includeArticle,
    orderBy: [{ NomArticle: 'asc' }, { ID_Article: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getArticle = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant article");

  const data = await prisma.t_Article.findUnique({
    where: { ID_Article: id },
    include: {
      ...includeArticle,
      T_Mouvement: {
        take: 10,
        orderBy: [{ DateMvt: 'desc' }, { ID_Mvt: 'desc' }],
      },
      T_CommandeDetail: {
        include: {
          T_Commande: {
            select: {
              ID_Commande: true,
              CodeCmd: true,
              DateCmd: true,
            },
          },
        },
      },
    },
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Article introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createArticle = catchAsync(async (req, res) => {
  const { NomArticle, PUArticle, PVArticle } = req.body;

  if (!NomArticle || PUArticle == null || PVArticle == null) {
    return res.status(400).json({
      success: false,
      message: 'NomArticle, PUArticle et PVArticle sont obligatoires.',
    });
  }

  const data = await prisma.t_Article.create({
    data: req.body,
    include: includeArticle,
  });

  res.status(201).json({ success: true, data });
});

const updateArticle = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant article");

  const data = await prisma.t_Article.update({
    where: { ID_Article: id },
    data: req.body,
    include: includeArticle,
  });

  res.json({ success: true, data });
});

const removeArticle = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant article");

  await prisma.t_Article.delete({
    where: { ID_Article: id },
  });

  res.json({
    success: true,
    message: 'Article supprime.',
  });
});

const listProfessionnels = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Professionnel.findMany({
    where: q
      ? {
          OR: [
            {
              T_Utilisateurs: {
                NomUser: buildContains(q),
              },
            },
            {
              T_Utilisateurs: {
                PrenomUser: buildContains(q),
              },
            },
            {
              T_Utilisateurs: {
                EmailUser: buildContains(q),
              },
            },
            {
              T_GeneriqueSpecialite: {
                NomGenerique: buildContains(q),
              },
            },
            { NumeroIdentification: buildContains(q) },
          ],
        }
      : undefined,
    include: includeProfessionnel,
    orderBy: [{ IdProfessionnel: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getProfessionnel = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant professionnel");

  const data = await prisma.t_Professionnel.findUnique({
    where: { IdProfessionnel: id },
    include: includeProfessionnel,
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Professionnel introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const listRecherches = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();
  const userId = req.query.userId ? parseId(req.query.userId, "Identifiant utilisateur") : undefined;

  const data = await prisma.t_Recherche.findMany({
    where: {
      ...(q ? { TexteRecherche: buildContains(q) } : {}),
      ...(userId ? { IdUserFk: userId } : {}),
    },
    include: includeRecherche,
    orderBy: [{ DateRecherche: 'desc' }, { IdRecherche: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getRecherche = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant recherche");

  const data = await prisma.t_Recherche.findUnique({
    where: { IdRecherche: id },
    include: includeRecherche,
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Recherche introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createRecherche = catchAsync(async (req, res) => {
  const { TexteRecherche } = req.body;

  if (!TexteRecherche) {
    return res.status(400).json({
      success: false,
      message: 'TexteRecherche est obligatoire.',
    });
  }

  const data = await prisma.t_Recherche.create({
    data: req.body,
    include: includeRecherche,
  });

  res.status(201).json({ success: true, data });
});

const removeRecherche = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant recherche");

  await prisma.t_Recherche.delete({
    where: { IdRecherche: id },
  });

  res.json({
    success: true,
    message: 'Recherche supprimee.',
  });
});

const listCommandes = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const code = req.query.code?.trim();
  const userId = req.query.userId ? parseId(req.query.userId, "Identifiant utilisateur") : undefined;

  const data = await prisma.t_Commande.findMany({
    where: {
      ...(code ? { CodeCmd: buildContains(code) } : {}),
      ...(userId ? { ID_UserFk: userId } : {}),
    },
    include: includeCommande,
    orderBy: [{ DateCmd: 'desc' }, { ID_Commande: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: buildListMeta(data, take, skip),
  });
});

const getCommande = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant commande");

  const data = await prisma.t_Commande.findUnique({
    where: { ID_Commande: id },
    include: includeCommande,
  });

  if (!data) {
    return res.status(404).json({
      success: false,
      message: 'Commande introuvable.',
    });
  }

  return res.json({ success: true, data });
});

const createCommande = catchAsync(async (req, res) => {
  const { details = [], ...commandeData } = req.body;

  const data = await prisma.$transaction(async (tx) => {
    const createdCommande = await tx.t_Commande.create({
      data: commandeData,
    });

    if (Array.isArray(details) && details.length > 0) {
      await Promise.all(
        details.map((detail) =>
          tx.t_CommandeDetail.create({
            data: {
              ID_CmdFk: createdCommande.ID_Commande,
              ID_ArticleFk: detail.ID_ArticleFk,
              QteCmdDetail: detail.QteCmdDetail ?? null,
              PUCmdDetail: detail.PUCmdDetail ?? null,
              ObsCmdDetail: detail.ObsCmdDetail ?? null,
              RemiseCmdDetail: detail.RemiseCmdDetail ?? null,
              LieuCmdDetail: detail.LieuCmdDetail ?? null,
              SelectCmdDetail: detail.SelectCmdDetail ?? null,
            },
          })
        )
      );
    }

    return tx.t_Commande.findUnique({
      where: { ID_Commande: createdCommande.ID_Commande },
      include: includeCommande,
    });
  });

  res.status(201).json({ success: true, data });
});

const updateCommande = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant commande");
  const { details, replaceDetails, ...commandeData } = req.body;

  const data = await prisma.$transaction(async (tx) => {
    await tx.t_Commande.update({
      where: { ID_Commande: id },
      data: commandeData,
    });

    if (replaceDetails === true) {
      await tx.t_CommandeDetail.deleteMany({
        where: { ID_CmdFk: id },
      });

      if (Array.isArray(details) && details.length > 0) {
        await Promise.all(
          details.map((detail) =>
            tx.t_CommandeDetail.create({
              data: {
                ID_CmdFk: id,
                ID_ArticleFk: detail.ID_ArticleFk,
                QteCmdDetail: detail.QteCmdDetail ?? null,
                PUCmdDetail: detail.PUCmdDetail ?? null,
                ObsCmdDetail: detail.ObsCmdDetail ?? null,
                RemiseCmdDetail: detail.RemiseCmdDetail ?? null,
                LieuCmdDetail: detail.LieuCmdDetail ?? null,
                SelectCmdDetail: detail.SelectCmdDetail ?? null,
              },
            })
          )
        );
      }
    }

    return tx.t_Commande.findUnique({
      where: { ID_Commande: id },
      include: includeCommande,
    });
  });

  res.json({ success: true, data });
});

const removeCommande = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant commande");

  await prisma.t_Commande.delete({
    where: { ID_Commande: id },
  });

  res.json({
    success: true,
    message: 'Commande supprimee.',
  });
});

module.exports = {
  createArticle,
  createCommande,
  createEntite,
  createProfessionnel: undefined,
  createRecherche,
  createUtilisateur,
  getArticle,
  getCommande,
  getEntite,
  getLicence,
  getProfessionnel,
  getRecherche,
  getUtilisateur,
  listArticles,
  listCommandes,
  listEntites,
  listLicences,
  listProfessionnels,
  listRecherches,
  listUtilisateurs,
  removeArticle,
  removeCommande,
  removeEntite,
  removeLicence,
  removeRecherche,
  removeUtilisateur,
  updateArticle,
  updateCommande,
  updateEntite,
  updateLicence,
  updateUtilisateur,
  createLicence,
};
