const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const userRoutes = require('./userRoutes');
const walletRoutes = require('./walletRoutes');
const arenaRoutes = require('./arenaRoutes');
const notificationRoutes = require('./notificationRoutes');
const syncRoutes = require('./syncRoutes');
const gameRoutes = require('./gameRoutes');
const adminRoutes = require('./adminRoutes');

// Health check route
router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    service: 'Tournament Arena Backend',
    database: 'SQLite (in-built node:sqlite)'
  });
});

// System Settings route
router.get('/settings', (req, res) => {
  try {
    const { db } = require('../config/database');
    const rows = db.prepare('SELECT * FROM system_settings').all();
    const settings = {};
    for (const r of rows) settings[r.key] = r.value;
    return res.json({
      success: true,
      data: {
        minDeposit: parseInt(settings.min_deposit || '50', 10),
        minWithdrawal: parseInt(settings.min_withdrawal || '50', 10),
        maxDeposit: parseInt(settings.max_deposit || '50000', 10),
        maxWithdrawal: parseInt(settings.max_withdrawal || '100000', 10)
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: 'Failed to fetch settings' });
  }
});

router.use('/auth', authRoutes);
router.use('/user', userRoutes);
router.use('/wallet', walletRoutes);
router.use('/arenas', arenaRoutes);
router.use('/notifications', notificationRoutes);
router.use('/sync', syncRoutes);
router.use('/games', gameRoutes);
router.use('/admin', adminRoutes);

module.exports = router;
