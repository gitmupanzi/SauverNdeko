const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');

const DEFAULT_TAKE = 20;
const MAX_TAKE = 100;

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
  const { NomUser, PrenomUser, EmailUser, MotdepasseUser, SexeUser, PhoneUser, IdRoleFk, IdEntiteFk } = req.body;

  if (!NomUser || !PrenomUser || !EmailUser || !MotdepasseUser || !SexeUser) {
    return res.status(400).json({
      success: false,
      message: 'Nom, prenom, email, mot de passe et sexe sont obligatoires.',
    });
  }

  const existingUser = await prisma.t_Utilisateurs.findUnique({
    where: { EmailUser },
  });

  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: 'Un utilisateur avec cet email existe deja.',
    });
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
      IdRoleFk: IdRoleFk || null,
      IdEntiteFk: IdEntiteFk || null,
    },
    include: includeUser,
  });

  res.status(201).json({ success: true, data });
});

const updateUtilisateur = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant utilisateur");
  const payload = { ...req.body };

  if (payload.MotdepasseUser) {
    payload.MotdepasseUser = await bcrypt.hash(payload.MotdepasseUser, 10);
  }

  const data = await prisma.t_Utilisateurs.update({
    where: { IdUser: id },
    data: payload,
    include: includeUser,
  });

  res.json({ success: true, data });
});

const removeUtilisateur = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant utilisateur");

  await prisma.t_Utilisateurs.delete({
    where: { IdUser: id },
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
  const { NomEntite, EmailEntite } = req.body;

  if (!NomEntite || !EmailEntite) {
    return res.status(400).json({
      success: false,
      message: 'NomEntite et EmailEntite sont obligatoires.',
    });
  }

  const data = await prisma.t_Entite.create({
    data: req.body,
    include: includeEntity,
  });

  res.status(201).json({ success: true, data });
});

const updateEntite = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant entite");

  const data = await prisma.t_Entite.update({
    where: { IdEntite: id },
    data: req.body,
    include: includeEntity,
  });

  res.json({ success: true, data });
});

const removeEntite = catchAsync(async (req, res) => {
  const id = parseId(req.params.id, "Identifiant entite");

  await prisma.t_Entite.delete({
    where: { IdEntite: id },
  });

  res.json({
    success: true,
    message: 'Entite supprimee.',
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
  getProfessionnel,
  getRecherche,
  getUtilisateur,
  listArticles,
  listCommandes,
  listEntites,
  listProfessionnels,
  listRecherches,
  listUtilisateurs,
  removeArticle,
  removeCommande,
  removeEntite,
  removeRecherche,
  removeUtilisateur,
  updateArticle,
  updateCommande,
  updateEntite,
  updateUtilisateur,
};
