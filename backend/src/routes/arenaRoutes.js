const express = require('express');
const router = express.Router();
const arenaController = require('../controllers/arenaController');

router.get('/', arenaController.getArenas);
router.post('/', arenaController.createArena);
router.post('/:arenaId/join', arenaController.joinArena);
router.post('/:arenaId/leave', arenaController.leaveArena);
router.post('/:arenaId/claim-win', arenaController.claimPrizeWin);

module.exports = router;
