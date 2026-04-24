const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const {
  createAccessToken,
  createRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} = require('../utils/jwt');
const { getUserModel, sanitizeUser } = require('../utils/userModel');

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

const register = async (req, res, next) => {
  try {
    const { delegate } = getUserModel(prisma);
    const { NomUser, PrenomUser, EmailUser, MotdepasseUser, SexeUser, PhoneUser, IdEntiteFk, IdRoleFk } = req.body;

    if (!NomUser || !PrenomUser || !EmailUser || !MotdepasseUser || !SexeUser) {
      return res.status(400).json({
        success: false,
        message: 'Nom, prenom, email, mot de passe et sexe sont obligatoires.',
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
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec cet email existe deja.',
      });
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
      },
    });

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
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Adresse email ou mot de passe incorrect.',
      });
    }

    const isValid = await comparePassword(MotdepasseUser, user.MotdepasseUser);

    if (!isValid) {
      return res.status(401).json({
        success: false,
        message: 'Adresse email ou mot de passe incorrect.',
      });
    }

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

const logout = async (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Deconnexion geree cote client.',
  });
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
  verifySession,
};
