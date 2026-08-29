const { db } = require('../config/database');
const {
  formatUser,
  formatWallet,
  formatArena,
  formatTransaction,
  formatWithdrawal,
  formatNotification
} = require('../utils/helpers');

exports.syncFullState = (req, res) => {
  try {
    const { userId } = req.params;

    // 1. Fetch or create default user
    let userRow = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!userRow) {
      // Return default first user if exists, or null
      userRow = db.prepare('SELECT * FROM users ORDER BY joined_at ASC LIMIT 1').get();
    }

    const effectiveUserId = userRow ? userRow.id : userId;
    const now = new Date().toISOString();

    // Mark user as actively online
    if (effectiveUserId) {
      db.prepare('UPDATE users SET last_seen_at = ? WHERE id = ?').run(now, effectiveUserId);
    }

    // 2. Fetch Wallet
    let walletRow = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(effectiveUserId);
    if (!walletRow && userRow) {
      const now = new Date().toISOString();
      db.prepare(`
        INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
        VALUES (?, 500, 250, 100, ?)
      `).run(effectiveUserId, now);
      walletRow = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(effectiveUserId);
    }

    // 3. Fetch Arenas
    const arenaRows = db.prepare('SELECT * FROM arenas ORDER BY start_time ASC').all();
    const arenas = arenaRows.map(a => {
      const participants = db.prepare('SELECT * FROM arena_participants WHERE arena_id = ?').all(a.id);
      return formatArena(a, participants);
    });

    // 4. Fetch Transactions
    const txnRows = db.prepare('SELECT * FROM transactions WHERE user_id = ? ORDER BY timestamp DESC').all(effectiveUserId);
    const transactions = txnRows.map(formatTransaction);

    // 5. Fetch Withdrawals (Auto-advance requested to processing after 4 hours)
    const fourHoursAgo = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();
    db.prepare(`
      UPDATE withdrawal_requests
      SET status = 'processing'
      WHERE status = 'requested' AND created_at <= ?
    `).run(fourHoursAgo);

    const wthRows = db.prepare('SELECT * FROM withdrawal_requests WHERE user_id = ? ORDER BY created_at DESC').all(effectiveUserId);
    const withdrawals = wthRows.map(formatWithdrawal);

    // 6. Fetch Notifications
    const notifRows = db.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY timestamp DESC').all(effectiveUserId);
    const notifications = notifRows.map(formatNotification);

    // 7. Fetch System Settings
    const settingRows = db.prepare('SELECT * FROM system_settings').all();
    const settingsMap = {};
    for (const r of settingRows) settingsMap[r.key] = r.value;

    const settings = {
      minDeposit: parseInt(settingsMap.min_deposit || '50', 10),
      minWithdrawal: parseInt(settingsMap.min_withdrawal || '50', 10),
      maxDeposit: parseInt(settingsMap.max_deposit || '50000', 10),
      maxWithdrawal: parseInt(settingsMap.max_withdrawal || '100000', 10),
      razorpayKeyId: settingsMap.razorpay_key_id || 'rzp_test_YOUR_KEY_ID',
      razorpayEnabled: settingsMap.razorpay_enabled !== 'false',
      razorpayMode: settingsMap.razorpay_mode || 'test'
    };

    return res.json({
      success: true,
      data: {
        user: formatUser(userRow),
        wallet: formatWallet(walletRow),
        arenas: arenas,
        transactions: transactions,
        withdrawals: withdrawals,
        notifications: notifications,
        settings: settings
      }
    });
  } catch (error) {
    console.error('Sync full state error:', error);
    return res.status(500).json({ success: false, error: 'Database sync error' });
  }
};
