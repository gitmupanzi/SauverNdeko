const prisma = require('../config/db');
const { getUserModel, userProfileSelect } = require('../utils/userModel');

module.exports = async (req, res, next) => {
  try {
    if (!Number.isInteger(req.userId)) {
      return res.status(401).json({
        success: false,
        message: 'Session utilisateur introuvable.',
      });
    }

    const { delegate } = getUserModel(prisma);
    const user = await delegate.findUnique({
      where: {
        IdUser: req.userId,
      },
      select: userProfileSelect,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur introuvable.',
      });
    }

    const roleName = String(user.T_Generique?.NomGenerique || '').toLowerCase();
    const canAccessAdmin =
      Boolean(user.Is_Admin) || Boolean(user.Is_staff) || ['admin', 'administrateur'].includes(roleName);

    if (!canAccessAdmin) {
      return res.status(403).json({
        success: false,
        message: "Acces reserve aux administrateurs.",
      });
    }

    req.adminUser = user;
    return next();
  } catch (error) {
    return next(error);
  }
};
