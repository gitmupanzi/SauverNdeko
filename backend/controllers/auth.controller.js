const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const {
  createAccessToken,
  createRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} = require('../utils/jwt');
const { getUserModel, sanitizeUser, userAuthSelect, userProfileSelect } = require('../utils/userModel');

const comparePassword = async (plainPassword, storedPassword) => {
  if (!storedPassword) {
    return false;
  }

  if (storedPassword.startsWith('$2a$') || storedPassword.startsWith('$2b$') || storedPassword.startsWith('$2y$')) {
    return bcrypt.compare(plainPassword, storedPassword);
  }

  return plainPassword === storedPassword;
};

const buildAuthPayload = (user) => ({
  accessToken: createAccessToken(user.IdUser),
  refreshToken: createRefreshToken(user.IdUser),
  user: sanitizeUser(user),
});

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const defaultRoleCandidates = ['Utilisateur', 'User', 'Client', 'Patient'];

const normalizeOptionalString = (value) => {
  if (value == null) {
    return undefined;
  }

  const normalized = String(value).trim();
  return normalized;
};

const parseOptionalPositiveInt = (value, label = 'identifiant') => {
  if (value == null || value === '') {
    return null;
  }

  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    const error = new Error(`${label} invalide.`);
    error.statusCode = 400;
    throw error;
  }

  return parsed;
};

const loginHistoryTypeCandidatesByAction = {
  login: ['Connexion', 'Login'],
  logout: ['D\u00e9connexion', 'Deconnexion', 'Logout'],
};

const resolveLoginTypeId = async (action = 'login') => {
  const candidates = loginHistoryTypeCandidatesByAction[action] || loginHistoryTypeCandidatesByAction.login;

  const namedType = await prisma.t_Generique.findFirst({
    where: {
      T_CategorieGenerique: {
        NomCategorieGenerique: {
          equals: 'Type login',
          mode: 'insensitive',
        },
      },
      OR: candidates.flatMap((value) => [
        {
          NomGenerique: {
            equals: value,
            mode: 'insensitive',
          },
        },
        {
          AbrGenerique: {
            equals: value,
            mode: 'insensitive',
          },
        },
      ]),
    },
    select: {
      ID_Generique: true,
    },
  });

  if (namedType?.ID_Generique) {
    return namedType.ID_Generique;
  }

  const fallbackType = await prisma.t_Generique.findFirst({
    where: {
      T_CategorieGenerique: {
        NomCategorieGenerique: {
          equals: 'Type login',
          mode: 'insensitive',
        },
      },
    },
    orderBy: {
      ID_Generique: 'asc',
    },
    select: {
      ID_Generique: true,
    },
  });

  return fallbackType?.ID_Generique || null;
};

const recordLoginHistory = async (user, action = 'login') => {
  try {
    const loginTypeId = await resolveLoginTypeId(action);

    if (!loginTypeId) {
      return;
    }

    await prisma.t_Login.create({
      data: {
        IdUserFk: user.IdUser,
        IdTypeLoginFk: loginTypeId,
        IdEntiteFk: user.IdEntiteFk || null,
      },
    });
  } catch (error) {
    console.warn(`Impossible d'enregistrer l'historique ${action}.`, error.message);
  }
};

const resolveDefaultPublicRoleId = async () => {
  const role = await prisma.t_Generique.findFirst({
    where: {
      T_CategorieGenerique: {
        NomCategorieGenerique: {
          equals: 'Role',
          mode: 'insensitive',
        },
      },
      OR: defaultRoleCandidates.flatMap((value) => [
        {
          NomGenerique: {
            equals: value,
            mode: 'insensitive',
          },
        },
        {
          AbrGenerique: {
            equals: value,
            mode: 'insensitive',
          },
        },
      ]),
    },
    select: {
      ID_Generique: true,
    },
  });

  return role?.ID_Generique || null;
};

const register = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const NomUser = normalizeOptionalString(req.body?.NomUser);
    const PrenomUser = normalizeOptionalString(req.body?.PrenomUser);
    const EmailUser = normalizeOptionalString(req.body?.EmailUser);
    const MotdepasseUser = typeof req.body?.MotdepasseUser === 'string' ? req.body.MotdepasseUser : '';
    const SexeUser = normalizeOptionalString(req.body?.SexeUser);
    const PhoneUser = normalizeOptionalString(req.body?.PhoneUser);
    const IdEntiteFk = parseOptionalPositiveInt(req.body?.IdEntiteFk, 'Entite');
    let IdRoleFk = parseOptionalPositiveInt(req.body?.IdRoleFk, 'Role');

    if (!NomUser || !PrenomUser || !EmailUser || !MotdepasseUser || !SexeUser) {
      return res.status(400).json({
        success: false,
        message: 'Nom, prenom, email, mot de passe et sexe sont obligatoires.',
      });
    }

    if (!EMAIL_REGEX.test(EmailUser)) {
      return res.status(400).json({
        success: false,
        message: 'Adresse email invalide.',
      });
    }

    if (!['M', 'F'].includes(SexeUser)) {
      return res.status(400).json({
        success: false,
        message: 'Le sexe doit etre "M" ou "F".',
      });
    }

    const existingUser = await delegate.findUnique({
      where: { EmailUser },
      select: {
        IdUser: true,
      },
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec cet email existe deja.',
      });
    }

    if (PhoneUser) {
      const existingPhoneUser = await delegate.findFirst({
        where: {
          PhoneUser,
        },
        select: {
          IdUser: true,
        },
      });

      if (existingPhoneUser) {
        return res.status(409).json({
          success: false,
          message: 'Un utilisateur avec ce numero de telephone existe deja.',
        });
      }
    }

    if (IdEntiteFk) {
      const entite = await prisma.t_Entite.findUnique({
        where: {
          IdEntite: IdEntiteFk,
        },
        select: {
          IdEntite: true,
        },
      });

      if (!entite) {
        return res.status(404).json({
          success: false,
          message: 'Entite introuvable.',
        });
      }
    }

    if (IdRoleFk) {
      const role = await prisma.t_Generique.findFirst({
        where: {
          ID_Generique: IdRoleFk,
          T_CategorieGenerique: {
            NomCategorieGenerique: {
              equals: 'Role',
              mode: 'insensitive',
            },
          },
        },
        select: {
          ID_Generique: true,
        },
      });

      if (!role) {
        return res.status(404).json({
          success: false,
          message: 'Role introuvable.',
        });
      }
    } else {
      IdRoleFk = await resolveDefaultPublicRoleId();
    }

    const hashedPassword = await bcrypt.hash(MotdepasseUser, 10);

    const user = await delegate.create({
      data: {
        NomUser,
        PrenomUser,
        EmailUser,
        MotdepasseUser: hashedPassword,
        SexeUser,
        PhoneUser: PhoneUser || null,
        IdEntiteFk: IdEntiteFk || null,
        IdRoleFk: IdRoleFk || null,
        Is_staff: false,
        Is_Admin: false,
      },
      select: userProfileSelect,
    });

    await recordLoginHistory(user, 'login');

    return res.status(201).json({
      success: true,
      message: 'Utilisateur cree avec succes.',
      ...buildAuthPayload(user),
    });
  } catch (error) {
    return next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const { EmailUser, MotdepasseUser } = req.body;

    if (!EmailUser || !MotdepasseUser) {
      return res.status(400).json({
        success: false,
        message: 'Email et mot de passe sont obligatoires.',
      });
    }

    const user = await delegate.findUnique({
      where: { EmailUser },
      select: userAuthSelect,
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Adresse email ou mot de passe incorrect.',
      });
    }

    if (!user.ValideUser) {
      return res.status(403).json({
        success: false,
        message: 'Ce compte utilisateur est desactive.',
      });
    }

    const isValid = await comparePassword(MotdepasseUser, user.MotdepasseUser);

    if (!isValid) {
      return res.status(401).json({
        success: false,
        message: 'Adresse email ou mot de passe incorrect.',
      });
    }

    await recordLoginHistory(user, 'login');

    return res.status(200).json({
      success: true,
      message: 'Connexion reussie.',
      ...buildAuthPayload(user),
    });
  } catch (error) {
    return next(error);
  }
};

const currentUser = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);

    const user = await delegate.findUnique({
      where: { IdUser: req.userId },
      select: userProfileSelect,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable.',
      });
    }

    return res.status(200).json({
      success: true,
      data: sanitizeUser(user),
    });
  } catch (error) {
    return next(error);
  }
};

const updateCurrentUser = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const currentUserRecord = await delegate.findUnique({
      where: { IdUser: req.userId },
      select: userProfileSelect,
    });

    if (!currentUserRecord) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable.',
      });
    }

    const nextNomUser = normalizeOptionalString(req.body?.NomUser);
    const nextPrenomUser = normalizeOptionalString(req.body?.PrenomUser);
    const nextEmailUser = normalizeOptionalString(req.body?.EmailUser);
    const nextPhoneUser = normalizeOptionalString(req.body?.PhoneUser);
    const nextSexeUser = normalizeOptionalString(req.body?.SexeUser);
    const nextUrlPhoto = normalizeOptionalString(req.body?.UrlPhoto);

    const data = {};

    if (nextNomUser !== undefined) {
      if (!nextNomUser) {
        return res.status(400).json({
          success: false,
          message: 'Le nom est obligatoire.',
        });
      }

      data.NomUser = nextNomUser;
    }

    if (nextPrenomUser !== undefined) {
      if (!nextPrenomUser) {
        return res.status(400).json({
          success: false,
          message: 'Le prenom est obligatoire.',
        });
      }

      data.PrenomUser = nextPrenomUser;
    }

    if (nextEmailUser !== undefined) {
      if (!nextEmailUser || !EMAIL_REGEX.test(nextEmailUser)) {
        return res.status(400).json({
          success: false,
          message: 'Adresse email invalide.',
        });
      }

      data.EmailUser = nextEmailUser;
    }

    if (nextPhoneUser !== undefined) {
      data.PhoneUser = nextPhoneUser || null;
    }

    if (nextSexeUser !== undefined) {
      if (!['M', 'F'].includes(nextSexeUser)) {
        return res.status(400).json({
          success: false,
          message: 'Le sexe doit etre "M" ou "F".',
        });
      }

      data.SexeUser = nextSexeUser;
    }

    if (nextUrlPhoto !== undefined) {
      data.UrlPhoto = nextUrlPhoto || null;
    }

    if (Object.keys(data).length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Aucune modification valide a enregistrer.',
      });
    }

    if (data.EmailUser || data.PhoneUser !== undefined) {
      const conflictClauses = [];

      if (data.EmailUser && data.EmailUser !== currentUserRecord.EmailUser) {
        conflictClauses.push({ EmailUser: data.EmailUser });
      }

      if (
        data.PhoneUser !== undefined &&
        data.PhoneUser &&
        data.PhoneUser !== currentUserRecord.PhoneUser
      ) {
        conflictClauses.push({ PhoneUser: data.PhoneUser });
      }

      if (conflictClauses.length > 0) {
        const conflictingUser = await delegate.findFirst({
          where: {
            IdUser: {
              not: req.userId,
            },
            OR: conflictClauses,
          },
          select: {
            IdUser: true,
            EmailUser: true,
            PhoneUser: true,
          },
        });

        if (conflictingUser) {
          return res.status(409).json({
            success: false,
            message:
              conflictingUser.EmailUser === data.EmailUser
                ? 'Un utilisateur avec cet email existe deja.'
                : 'Un utilisateur avec ce numero de telephone existe deja.',
          });
        }
      }
    }

    data.DateModificationUser = new Date();

    const user = await delegate.update({
      where: { IdUser: req.userId },
      data,
      select: userProfileSelect,
    });

    return res.status(200).json({
      success: true,
      message: 'Profil mis a jour avec succes.',
      data: sanitizeUser(user),
    });
  } catch (error) {
    return next(error);
  }
};

const refresh = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token requis.',
      });
    }

    const decoded = verifyRefreshToken(refreshToken);
    const user = await delegate.findUnique({
      where: { IdUser: decoded.userId },
      select: {
        IdUser: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable.',
      });
    }

    return res.status(200).json({
      success: true,
      accessToken: createAccessToken(user.IdUser),
      refreshToken: createRefreshToken(user.IdUser),
    });
  } catch (error) {
    return next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const user = await delegate.findUnique({
      where: { IdUser: req.userId },
      select: {
        IdUser: true,
        IdEntiteFk: true,
      },
    });

    if (user) {
      await recordLoginHistory(user, 'logout');
    }

    return res.status(200).json({
      success: true,
      message: 'Deconnexion enregistree avec succes.',
    });
  } catch (error) {
    return next(error);
  }
};

const verifySession = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Token manquant ou invalide.',
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    return res.status(200).json({
      success: true,
      data: decoded,
    });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  currentUser,
  login,
  logout,
  refresh,
  register,
  updateCurrentUser,
  verifySession,
};
