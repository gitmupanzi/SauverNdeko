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

const publicArticleSelect = {
  ID_Article: true,
  NomArticle: true,
  RefArticle: true,
  PVArticle: true,
  PhotoArticle: true,
  ObsArticle: true,
  ValideArticle: true,
};

const publicEntiteSelect = {
  IdEntite: true,
  NomEntite: true,
  PhoneEntite: true,
  AdresseEntite: true,
  ValideEntite: true,
  T_Generique: {
    select: {
      ID_Generique: true,
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
};

const publicExpertSelect = {
  IdProfessionnel: true,
  ExperienceAns: true,
  ValideProfessionnel: true,
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
  T_Utilisateurs: {
    select: {
      NomUser: true,
      PrenomUser: true,
      UrlPhoto: true,
    },
  },
  T_Professionnel_Entite: {
    select: {
      EstPrincipal: true,
      T_Entite: {
        select: {
          IdEntite: true,
          NomEntite: true,
          PhoneEntite: true,
          AdresseEntite: true,
        },
      },
    },
  },
};

const publicDiseaseSelect = {
  ID_Generique: true,
  NomGenerique: true,
  AbrGenerique: true,
  ObsGenerique: true,
  T_CategorieGenerique: {
    select: {
      ID_CategorieGenerique: true,
      NomCategorieGenerique: true,
    },
  },
};

const listPublicArticles = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Article.findMany({
    where: {
      ValideArticle: true,
      ...(q
        ? {
            OR: [
              { NomArticle: buildContains(q) },
              { RefArticle: buildContains(q) },
              { ObsArticle: buildContains(q) },
            ],
          }
        : {}),
    },
    select: publicArticleSelect,
    orderBy: [{ NomArticle: 'asc' }, { ID_Article: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: { take, skip, count: data.length },
  });
});

const listPublicPharmacies = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Entite.findMany({
    where: q
      ? {
          OR: [
            { NomEntite: buildContains(q) },
            { AdresseEntite: buildContains(q) },
            { PhoneEntite: buildContains(q) },
          ],
        }
      : undefined,
    select: publicEntiteSelect,
    orderBy: [{ NomEntite: 'asc' }, { IdEntite: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: { take, skip, count: data.length },
  });
});

const listPublicExperts = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Professionnel.findMany({
    where: q
      ? {
          OR: [
            { T_Utilisateurs: { is: { NomUser: buildContains(q) } } },
            { T_Utilisateurs: { is: { PrenomUser: buildContains(q) } } },
            { T_GeneriqueSpecialite: { is: { NomGenerique: buildContains(q) } } },
            { T_GeneriqueType: { is: { NomGenerique: buildContains(q) } } },
          ],
        }
      : undefined,
    select: publicExpertSelect,
    orderBy: [{ IdProfessionnel: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: { take, skip, count: data.length },
  });
});

const listPublicMaladies = catchAsync(async (req, res) => {
  const take = parseTake(req.query.take);
  const skip = parseSkip(req.query.skip);
  const q = req.query.q?.trim();

  const data = await prisma.t_Generique.findMany({
    where: {
      ValideGenerique: true,
      T_CategorieGenerique: {
        is: {
          NomCategorieGenerique: {
            equals: 'Maladie',
            mode: 'insensitive',
          },
        },
      },
      ...(q
        ? {
            OR: [
              { NomGenerique: buildContains(q) },
              { AbrGenerique: buildContains(q) },
              { ObsGenerique: buildContains(q) },
            ],
          }
        : {}),
    },
    select: publicDiseaseSelect,
    orderBy: [{ NomGenerique: 'asc' }, { ID_Generique: 'desc' }],
    take,
    skip,
  });

  res.json({
    success: true,
    data,
    meta: { take, skip, count: data.length },
  });
});

const getPublicStats = catchAsync(async (req, res) => {
  const [articlesCount, pharmaciesCount, expertsCount, diseasesCount, activeStructures] =
    await prisma.$transaction([
      prisma.t_Article.count({ where: { ValideArticle: true } }),
      prisma.t_Entite.count(),
      prisma.t_Professionnel.count(),
      prisma.t_Generique.count({
        where: {
          ValideGenerique: true,
          T_CategorieGenerique: {
            is: {
              NomCategorieGenerique: {
                equals: 'Maladie',
                mode: 'insensitive',
              },
            },
          },
        },
      }),
      prisma.t_Entite.count({ where: { ValideEntite: true } }),
    ]);

  res.json({
    success: true,
    data: {
      productsCount: articlesCount,
      pharmaciesCount,
      expertsCount,
      diseasesCount,
      activeStructures,
      latestAnnouncements: Math.min(articlesCount, 6),
      responseLabel: 'Réponse rapide',
    },
  });
});

const getPublicChatContext = catchAsync(async (req, res) => {
  const targetType = req.query.type;
  const id = parseId(req.query.id, 'Identifiant de conversation');

  if (targetType === 'expert') {
    const expert = await prisma.t_Professionnel.findUnique({
      where: { IdProfessionnel: id },
      select: publicExpertSelect,
    });

    if (!expert) {
      return res.status(404).json({
        success: false,
        message: 'Expert introuvable.',
      });
    }

    return res.json({
      success: true,
      data: {
        threadKey: `expert:${expert.IdProfessionnel}`,
        target: {
          id: expert.IdProfessionnel,
          type: 'expert',
          name: `${expert.T_Utilisateurs?.PrenomUser || ''} ${expert.T_Utilisateurs?.NomUser || ''}`.trim(),
          specialty: expert.T_GeneriqueSpecialite?.NomGenerique || 'Spécialité à confirmer',
          structure:
            expert.T_Professionnel_Entite?.find((item) => item.EstPrincipal)?.T_Entite?.NomEntite ||
            expert.T_Professionnel_Entite?.[0]?.T_Entite?.NomEntite ||
            'Structure à confirmer',
        },
        capabilities: {
          canBootstrapThread: true,
          canPersistMessages: false,
        },
      },
    });
  }

  if (targetType === 'structure') {
    const entite = await prisma.t_Entite.findUnique({
      where: { IdEntite: id },
      select: publicEntiteSelect,
    });

    if (!entite) {
      return res.status(404).json({
        success: false,
        message: 'Structure introuvable.',
      });
    }

    return res.json({
      success: true,
      data: {
        threadKey: `structure:${entite.IdEntite}`,
        target: {
          id: entite.IdEntite,
          type: 'structure',
          name: entite.NomEntite,
          specialty: entite.T_Generique?.NomGenerique || 'Structure de santé',
          structure: entite.PhoneEntite || 'Contact à confirmer',
        },
        capabilities: {
          canBootstrapThread: true,
          canPersistMessages: false,
        },
      },
    });
  }

  return res.status(400).json({
    success: false,
    message: 'Le parametre type doit etre expert ou structure.',
  });
});

module.exports = {
  getPublicChatContext,
  getPublicStats,
  listPublicArticles,
  listPublicExperts,
  listPublicMaladies,
  listPublicPharmacies,
};
