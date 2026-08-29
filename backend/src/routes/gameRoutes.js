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

// Mines Gold Game Routes
router.get('/mines/state', gameController.getMinesState);
router.get('/mines/history', gameController.getMinesHistory);
router.post('/mines/start', gameController.startMines);
router.post('/mines/reveal', gameController.revealMinesTile);
router.post('/mines/cashout', gameController.cashoutMines);

// Lucky Wheel Game Routes
router.get('/wheel/segments', gameController.getWheelSegments);
router.get('/wheel/history', gameController.getWheelHistory);
router.post('/wheel/spin', gameController.spinWheel);

// Cyber Dice Game Routes
router.get('/dice/history', gameController.getDiceHistory);
router.post('/dice/roll', gameController.rollDice);

module.exports = router;
