const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

router.put('/:userId/read-all', notificationController.markAllRead);
router.put('/:userId/:id/read', notificationController.markRead);

module.exports = router;
