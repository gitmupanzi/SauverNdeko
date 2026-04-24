const prisma = require('../config/db');
const catchAsync = require('../middlewares/catchAsync');
const { verifyAccessToken } = require('../utils/jwt');

const FALLBACK_DISCUSSION_USER_ID = Number(process.env.CHAT_TEST_USER_ID || process.env.DISCUSSION_TEST_USER_ID || 1);
const FALLBACK_DISCUSSION_USER_EMAIL =
  process.env.CHAT_TEST_USER_EMAIL || 'chat.demo@sauverndeko.local';
const fallbackActorSelect = {
  IdUser: true,
  NomUser: true,
  PrenomUser: true,
  UrlPhoto: true,
  IdEntiteFk: true,
  T_Professionnel: {
    select: {
      IdProfessionnel: true,
    },
  },
};

const publicAuthorSelect = {
  IdUser: true,
  NomUser: true,
  PrenomUser: true,
  UrlPhoto: true,
};

const publicExpertRecipientSelect = {
  IdProfessionnel: true,
  ExperienceAns: true,
  T_GeneriqueSpecialite: {
    select: {
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_GeneriqueType: {
    select: {
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
  T_Utilisateurs: {
    select: publicAuthorSelect,
  },
  T_Professionnel_Entite: {
    select: {
      EstPrincipal: true,
      T_Entite: {
        select: {
          IdEntite: true,
          NomEntite: true,
          AdresseEntite: true,
          PhoneEntite: true,
        },
      },
    },
  },
};

const publicStructureRecipientSelect = {
  IdEntite: true,
  NomEntite: true,
  PhoneEntite: true,
  AdresseEntite: true,
  T_Generique: {
    select: {
      NomGenerique: true,
      AbrGenerique: true,
    },
  },
};

const discussionSummarySelect = {
  IdDiscussion: true,
  TypeDiscussion: true,
  SujetDiscussion: true,
  DateCreation: true,
  DernierMessageAt: true,
  IdUserClientFk: true,
  IdProfessionnelFk: true,
  IdEntiteFk: true,
  T_Professionnel: {
    select: publicExpertRecipientSelect,
  },
  T_Entite: {
    select: publicStructureRecipientSelect,
  },
  T_Chat: {
    orderBy: [{ DateChat: 'desc' }, { IdChat: 'desc' }],
    take: 1,
    select: {
      IdChat: true,
      TextChat: true,
      ChatFile: true,
      ChatLink: true,
      DateChat: true,
      LuChat: true,
      AuthorIdFk: true,
      T_Utilisateurs: {
        select: publicAuthorSelect,
      },
    },
  },
};

const discussionAccessSelect = {
  IdDiscussion: true,
  IdUserClientFk: true,
  IdProfessionnelFk: true,
  IdEntiteFk: true,
  TypeDiscussion: true,
  SujetDiscussion: true,
  DateCreation: true,
  DernierMessageAt: true,
  T_Professionnel: {
    select: publicExpertRecipientSelect,
  },
  T_Entite: {
    select: publicStructureRecipientSelect,
  },
};

const parsePositiveInt = (value, label = 'identifiant') => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const normalizeDiscussionType = (value) => {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === 'expert' || normalized === 'structure' ? normalized : null;
};

const buildExpertRecipient = (expert) => {
  if (!expert) {
    return null;
  }

  const mainLink =
    expert.T_Professionnel_Entite?.find((item) => item.EstPrincipal) || expert.T_Professionnel_Entite?.[0] || null;
  const entity = mainLink?.T_Entite || null;

  return {
    type: 'expert',
    id: expert.IdProfessionnel,
    firstName: expert.T_Utilisateurs?.PrenomUser || '',
    lastName: expert.T_Utilisateurs?.NomUser || '',
    fullName: `${expert.T_Utilisateurs?.PrenomUser || ''} ${expert.T_Utilisateurs?.NomUser || ''}`.trim() || 'Expert',
    photo: expert.T_Utilisateurs?.UrlPhoto || null,
    professionalType: expert.T_GeneriqueType?.NomGenerique || 'Professionnel de sante',
    specialty: expert.T_GeneriqueSpecialite?.NomGenerique || 'Specialite a confirmer',
    experience: expert.ExperienceAns,
    structure: entity?.NomEntite || 'Structure a confirmer',
    structureId: entity?.IdEntite || null,
    publicAddress: entity?.AdresseEntite || null,
    publicPhone: entity?.PhoneEntite || null,
  };
};

const buildStructureRecipient = (structure) => {
  if (!structure) {
    return null;
  }

  return {
    type: 'structure',
    id: structure.IdEntite,
    name: structure.NomEntite,
    structureType: structure.T_Generique?.NomGenerique || 'Structure de sante',
    publicAddress: structure.AdresseEntite || null,
    publicPhone: structure.PhoneEntite || null,
  };
};

const serializeMessage = (message) => ({
  IdChat: message.IdChat,
  TextChat: message.TextChat,
  ChatFile: message.ChatFile,
  ChatLink: message.ChatLink,
  DateChat: message.DateChat,
  LuChat: message.LuChat,
  author: message.T_Utilisateurs
    ? {
        IdUser: message.T_Utilisateurs.IdUser,
        NomUser: message.T_Utilisateurs.NomUser,
        PrenomUser: message.T_Utilisateurs.PrenomUser,
        UrlPhoto: message.T_Utilisateurs.UrlPhoto,
      }
    : null,
});

const serializeDiscussion = (discussion) => {
  const lastMessage = discussion.T_Chat?.[0] ? serializeMessage(discussion.T_Chat[0]) : null;

  return {
    IdDiscussion: discussion.IdDiscussion,
    TypeDiscussion: discussion.TypeDiscussion,
    SujetDiscussion: discussion.SujetDiscussion,
    DateCreation: discussion.DateCreation,
    DernierMessageAt: discussion.DernierMessageAt,
    recipient:
      discussion.TypeDiscussion === 'expert'
        ? buildExpertRecipient(discussion.T_Professionnel)
        : buildStructureRecipient(discussion.T_Entite),
    lastMessage,
  };
};

const buildDiscussionSubject = (type, recipient) => {
  if (type === 'expert') {
    return `Discussion avec ${recipient?.fullName || 'un expert'}`;
  }

  return `Discussion avec ${recipient?.name || 'une structure'}`;
};

const resolveCurrentActor = async (req) => {
  let userId = Number.isInteger(req.userId) ? req.userId : null;
  const authHeader = req.headers.authorization;
  const explicitUserIdHeader = req.headers['x-user-id'];
  let usedFallbackUser = false;

  if (!userId && authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const decoded = verifyAccessToken(authHeader.split(' ')[1]);
      userId = decoded.userId;
    } catch (error) {
      const authError = new Error('Token invalide ou expire.');
      authError.statusCode = 403;
      throw authError;
    }
  }

  if (!userId && explicitUserIdHeader) {
    userId = parsePositiveInt(explicitUserIdHeader, 'Identifiant utilisateur');
  }

  if (!userId) {
    userId = FALLBACK_DISCUSSION_USER_ID;
    usedFallbackUser = true;
  }

  let actor = await prisma.t_Utilisateurs.findUnique({
    where: { IdUser: userId },
    select: fallbackActorSelect,
  });

  if (!actor && usedFallbackUser) {
    actor = await prisma.t_Utilisateurs.findUnique({
      where: { EmailUser: FALLBACK_DISCUSSION_USER_EMAIL },
      select: fallbackActorSelect,
    });
  }

  if (!actor && usedFallbackUser) {
    actor = await prisma.t_Utilisateurs.create({
      data: {
        NomUser: 'Chat',
        PrenomUser: 'Demo',
        EmailUser: FALLBACK_DISCUSSION_USER_EMAIL,
        MotdepasseUser: 'DISABLED_FALLBACK_USER',
        SexeUser: 'M',
      },
      select: fallbackActorSelect,
    });
  }

  if (!actor) {
    const error = new Error('Utilisateur de discussion introuvable.');
    error.statusCode = 404;
    throw error;
  }

  return {
    userId: actor.IdUser,
    professionalId: actor.T_Professionnel?.IdProfessionnel || null,
    entityId: actor.IdEntiteFk || null,
    profile: actor,
    usingFallbackUser: usedFallbackUser,
  };
};

const isDiscussionAccessible = (discussion, actor) => {
  if (!discussion || !actor) {
    return false;
  }

  return (
    discussion.IdUserClientFk === actor.userId ||
    (actor.professionalId && discussion.IdProfessionnelFk === actor.professionalId) ||
    (actor.entityId && discussion.IdEntiteFk === actor.entityId)
  );
};

const getDiscussionOrThrow = async (discussionId, actor) => {
  const discussion = await prisma.t_Discussion.findUnique({
    where: { IdDiscussion: discussionId },
    select: discussionAccessSelect,
  });

  if (!discussion) {
    const error = new Error('Discussion introuvable.');
    error.statusCode = 404;
    throw error;
  }

  if (!isDiscussionAccessible(discussion, actor)) {
    const error = new Error('Acces non autorise a cette discussion.');
    error.statusCode = 403;
    throw error;
  }

  return discussion;
};

const startDiscussion = catchAsync(async (req, res) => {
  const actor = await resolveCurrentActor(req);
  const type = normalizeDiscussionType(req.body?.type);
  const targetId = parsePositiveInt(req.body?.targetId, 'Identifiant cible');

  if (!type) {
    return res.status(400).json({
      success: false,
      message: 'Le type doit etre "expert" ou "structure".',
    });
  }

  let recipient = null;
  let where = null;

  if (type === 'expert') {
    const expert = await prisma.t_Professionnel.findUnique({
      where: { IdProfessionnel: targetId },
      select: publicExpertRecipientSelect,
    });

    if (!expert) {
      return res.status(404).json({
        success: false,
        message: 'Expert introuvable.',
      });
    }

    recipient = buildExpertRecipient(expert);
    where = {
      IdUserClientFk: actor.userId,
      IdProfessionnelFk: targetId,
      TypeDiscussion: 'expert',
      ValideDiscussion: true,
    };
  } else {
    const structure = await prisma.t_Entite.findUnique({
      where: { IdEntite: targetId },
      select: publicStructureRecipientSelect,
    });

    if (!structure) {
      return res.status(404).json({
        success: false,
        message: 'Structure introuvable.',
      });
    }

    recipient = buildStructureRecipient(structure);
    where = {
      IdUserClientFk: actor.userId,
      IdEntiteFk: targetId,
      TypeDiscussion: 'structure',
      ValideDiscussion: true,
    };
  }

  let discussion = await prisma.t_Discussion.findFirst({
    where,
    select: discussionSummarySelect,
    orderBy: [{ DernierMessageAt: 'desc' }, { DateCreation: 'desc' }],
  });

  let created = false;

  if (!discussion) {
    discussion = await prisma.t_Discussion.create({
      data:
        type === 'expert'
          ? {
              IdUserClientFk: actor.userId,
              IdProfessionnelFk: targetId,
              TypeDiscussion: 'expert',
              SujetDiscussion: buildDiscussionSubject(type, recipient),
            }
          : {
              IdUserClientFk: actor.userId,
              IdEntiteFk: targetId,
              TypeDiscussion: 'structure',
              SujetDiscussion: buildDiscussionSubject(type, recipient),
            },
      select: discussionSummarySelect,
    });
    created = true;
  }

  return res.status(created ? 201 : 200).json({
    success: true,
    data: serializeDiscussion(discussion),
    meta: {
      currentUserId: actor.userId,
      usingFallbackUser: actor.usingFallbackUser,
      created,
    },
  });
});

const listDiscussions = catchAsync(async (req, res) => {
  const actor = await resolveCurrentActor(req);

  const discussions = await prisma.t_Discussion.findMany({
    where: {
      ValideDiscussion: true,
      OR: [
        { IdUserClientFk: actor.userId },
        ...(actor.professionalId ? [{ IdProfessionnelFk: actor.professionalId }] : []),
        ...(actor.entityId ? [{ IdEntiteFk: actor.entityId }] : []),
      ],
    },
    select: discussionSummarySelect,
    orderBy: [{ DernierMessageAt: 'desc' }, { DateCreation: 'desc' }],
  });

  return res.json({
    success: true,
    data: discussions.map(serializeDiscussion),
    meta: {
      currentUserId: actor.userId,
      usingFallbackUser: actor.usingFallbackUser,
    },
  });
});

const listDiscussionMessages = catchAsync(async (req, res) => {
  const actor = await resolveCurrentActor(req);
  const discussionId = parsePositiveInt(req.params.id, 'Identifiant de discussion');

  await getDiscussionOrThrow(discussionId, actor);

  const messages = await prisma.t_Chat.findMany({
    where: { IdDiscussionFk: discussionId },
    orderBy: [{ DateChat: 'asc' }, { IdChat: 'asc' }],
    select: {
      IdChat: true,
      TextChat: true,
      ChatFile: true,
      ChatLink: true,
      DateChat: true,
      LuChat: true,
      T_Utilisateurs: {
        select: publicAuthorSelect,
      },
    },
  });

  return res.json({
    success: true,
    data: messages.map(serializeMessage),
    meta: {
      currentUserId: actor.userId,
      usingFallbackUser: actor.usingFallbackUser,
    },
  });
});

const postDiscussionMessage = catchAsync(async (req, res) => {
  const actor = await resolveCurrentActor(req);
  const discussionId = parsePositiveInt(req.params.id, 'Identifiant de discussion');
  const message = String(req.body?.message || '').trim();

  if (!message) {
    return res.status(400).json({
      success: false,
      message: 'Le message ne peut pas etre vide.',
    });
  }

  await getDiscussionOrThrow(discussionId, actor);

  const createdMessage = await prisma.$transaction(async (tx) => {
    const chat = await tx.t_Chat.create({
      data: {
        IdDiscussionFk: discussionId,
        AuthorIdFk: actor.userId,
        TextChat: message,
        LuChat: false,
      },
      select: {
        IdChat: true,
        TextChat: true,
        ChatFile: true,
        ChatLink: true,
        DateChat: true,
        LuChat: true,
        T_Utilisateurs: {
          select: publicAuthorSelect,
        },
      },
    });

    await tx.t_Discussion.update({
      where: { IdDiscussion: discussionId },
      data: {
        DernierMessageAt: chat.DateChat,
      },
    });

    return chat;
  });

  return res.status(201).json({
    success: true,
    data: serializeMessage(createdMessage),
    meta: {
      currentUserId: actor.userId,
      usingFallbackUser: actor.usingFallbackUser,
    },
  });
});

module.exports = {
  FALLBACK_DISCUSSION_USER_ID,
  listDiscussionMessages,
  listDiscussions,
  postDiscussionMessage,
  startDiscussion,
};
