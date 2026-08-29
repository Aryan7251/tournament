const express = require('express');
const router = express.Router();
const gameController = require('../controllers/gameController');

// Games Catalog
router.get('/catalog', gameController.getGameCatalog);

// Aviator Game Routes
router.get('/aviator/state', gameController.getAviatorState);
router.get('/aviator/history', gameController.getAviatorHistory);
router.post('/aviator/bet', gameController.placeAviatorBet);
router.post('/aviator/cancel-bet', gameController.cancelAviatorBet);
router.post('/aviator/cashout', gameController.cashoutAviatorBet);

module.exports = router;
