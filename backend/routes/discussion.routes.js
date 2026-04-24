const express = require('express');
const {
  listDiscussionMessages,
  listDiscussions,
  postDiscussionMessage,
  startDiscussion,
} = require('../controllers/discussion.controller');

const router = express.Router();

router.post('/start', startDiscussion);
router.get('/', listDiscussions);
router.get('/:id/messages', listDiscussionMessages);
router.post('/:id/messages', postDiscussionMessage);

module.exports = router;
