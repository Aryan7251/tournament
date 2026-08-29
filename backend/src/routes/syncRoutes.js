const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');

router.get('/:userId', syncController.syncFullState);

module.exports = router;
