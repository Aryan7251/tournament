const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');

// Razorpay Public Config & Webhook
router.get('/razorpay/config', walletController.getRazorpayConfig);
router.post('/razorpay/webhook', walletController.razorpayWebhook);

// Razorpay Order Creation & Verification
router.post('/:userId/razorpay/create-order', walletController.createRazorpayOrder);
router.post('/:userId/razorpay/verify', walletController.verifyRazorpayPayment);

// Legacy & Direct deposits/withdrawals
router.post('/:userId/deposit', walletController.depositFunds);
router.post('/:userId/withdraw', walletController.withdrawFunds);

module.exports = router;

