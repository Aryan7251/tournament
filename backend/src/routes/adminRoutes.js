const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { adminAuth } = require('../middleware/adminAuth');

// Public Admin Auth Route
router.post('/login', adminController.login);

// Enforce admin authentication for all administrative actions
router.use(adminAuth);

// Stats
router.get('/stats', adminController.getStats);

// User Management
router.get('/users', adminController.getUsers);
router.post('/users', adminController.addUser);
router.put('/users/:userId', adminController.updateUser);
router.delete('/users/:userId', adminController.deleteUser);

// KYC Verification
router.get('/kyc', adminController.getKycList);
router.put('/kyc/:userId', adminController.reviewKyc);

// Deposits & Manual Credits
router.get('/deposits', adminController.getDeposits);
router.post('/deposits/manual', adminController.manualDeposit);

// Withdrawals
router.get('/withdrawals', adminController.getWithdrawals);
router.put('/withdrawals/:id', adminController.reviewWithdrawal);

// Tournaments / Arenas
router.get('/arenas', adminController.getArenas);
router.post('/arenas', adminController.createArena);
router.put('/arenas/:id', adminController.updateArena);
router.delete('/arenas/:id', adminController.deleteArena);

// Aviator Game Engine
router.get('/aviator', adminController.getAviatorCockpit);
router.post('/aviator/control', adminController.controlAviator);

// Financial Settings (Min/Max Deposit & Withdrawal)
router.get('/settings', adminController.getSettings);
router.put('/settings', adminController.updateSettings);

module.exports = router;
