const express = require('express');
const verifyToken = require('../middlewares/verifyToken');
const {
  listDiscussionMessages,
  listDiscussions,
  postDiscussionMessage,
  startDiscussion,
} = require('../controllers/discussion.controller');

const router = express.Router();

router.use(verifyToken);

router.post('/start', startDiscussion);
router.get('/', listDiscussions);
router.get('/:id/messages', listDiscussionMessages);
router.post('/:id/messages', postDiscussionMessage);

module.exports = router;
