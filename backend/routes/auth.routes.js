const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const {
  currentUser,
  login,
  logout,
  refresh,
  register,
  updateCurrentUser,
  verifySession,
} = require('../controllers/auth.controller');

const router = express.Router();

router.post('/auth/login', login);
router.post('/auth/register', register);
router.post('/auth/refresh', refresh);
router.post('/auth/logout', verifyToken, logout);
router.get('/auth/me', verifyToken, currentUser);
router.put('/auth/me', verifyToken, updateCurrentUser);
router.get('/auth/verify', verifyToken, verifySession);

module.exports = router;
