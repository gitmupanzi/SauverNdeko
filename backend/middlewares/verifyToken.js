const { verifyAccessToken } = require('../utils/jwt');

module.exports = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Token manquant ou invalide.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = verifyAccessToken(token);
    req.userId = decoded.userId;
    return next();
  } catch (error) {
    return res.status(403).json({
      success: false,
      message: 'Token invalide ou expire.',
    });
  }
};
