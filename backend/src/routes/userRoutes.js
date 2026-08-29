const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');

router.put('/:userId', userController.updateProfile);
router.post('/:userId/kyc', userController.submitKyc);
router.post('/:userId/game-id', userController.saveGameId);
router.post('/:userId/payout', userController.savePayoutMethod);
router.post('/:userId/change-password', userController.changePassword);
router.post('/:userId/reset-account', userController.resetAccount);
router.post('/:userId/heartbeat', userController.heartbeat);

module.exports = router;
