const { db } = require('../config/database');
const bcrypt = require('bcryptjs');
const { aviatorEngine } = require('../services/aviatorEngine');
const { formatUser, formatWallet, formatArena } = require('../utils/helpers');
const { ADMIN_TOKEN } = require('../middleware/adminAuth');

// Server-side admin credentials (configurable via ENV for production)
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASS = process.env.ADMIN_PASS || 'admin';

// POST /api/admin/login
exports.login = (req, res) => {
  try {
    const { username, password } = req.body;
    if (username === ADMIN_USER && password === ADMIN_PASS) {
      return res.json({
        success: true,
        message: 'Admin authenticated successfully',
        token: ADMIN_TOKEN,
        admin: {
          username: ADMIN_USER,
          role: 'Super Administrator',
          loginTime: new Date().toISOString()
        }
      });
    }
    return res.status(401).json({ success: false, error: 'Invalid admin username or password' });
  } catch (error) {
    console.error('Admin login error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// GET /api/admin/stats - Analytics & Overview
exports.getStats = (req, res) => {
  try {
    const totalUsers = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
    const fifteenSecAgo = new Date(Date.now() - 15 * 1000).toISOString();
    const onlineUsers = db.prepare('SELECT COUNT(*) as count FROM users WHERE last_seen_at >= ?').get(fifteenSecAgo).count;

    const verifiedKyc = db.prepare("SELECT COUNT(*) as count FROM users WHERE kyc_status = 'verified'").get().count;
    const pendingKyc = db.prepare("SELECT COUNT(*) as count FROM users WHERE kyc_status = 'pending'").get().count;

    const totalDeposits = db.prepare("SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'deposit' AND status = 'completed'").get().total;
    const pendingDeposits = db.prepare("SELECT COUNT(*) as count FROM transactions WHERE type = 'deposit' AND status = 'pending'").get().count;

    const totalWithdrawals = db.prepare("SELECT COALESCE(SUM(amount), 0) as total FROM withdrawal_requests WHERE status = 'completed'").get().total;
    const pendingWithdrawals = db.prepare("SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total FROM withdrawal_requests WHERE status = 'pending'").get();

    const totalArenas = db.prepare('SELECT COUNT(*) as count FROM arenas').get().count;
    const liveArenas = db.prepare("SELECT COUNT(*) as count FROM arenas WHERE status = 'ongoing' OR status = 'live'").get().count;
    const completedArenas = db.prepare("SELECT COUNT(*) as count FROM arenas WHERE status = 'completed'").get().count;

    const walletBalances = db.prepare(`
      SELECT 
        COALESCE(SUM(deposit_balance), 0) as totalDeposit,
        COALESCE(SUM(winning_balance), 0) as totalWinning,
        COALESCE(SUM(bonus_balance), 0) as totalBonus
      FROM wallets
    `).get();

    const aviatorRoundsCount = db.prepare("SELECT COUNT(*) as count FROM game_rounds WHERE game_type = 'aviator'").get().count;
    const totalBetsPlaced = db.prepare("SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as totalAmount FROM game_bets").get();

    // Recent 10 transactions
    const recentTxns = db.prepare(`
      SELECT t.*, u.username, u.full_name
      FROM transactions t
      LEFT JOIN users u ON t.user_id = u.id
      ORDER BY t.timestamp DESC
      LIMIT 10
    `).all();

    // Chart data: past 7 days deposits & withdrawals
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      days.push(d.toISOString().slice(0, 10));
    }

    const dailyStats = days.map(day => {
      const dep = db.prepare(`
        SELECT COALESCE(SUM(amount), 0) as total
        FROM transactions
        WHERE type = 'deposit' AND status = 'completed' AND timestamp LIKE ?
      `).get(`${day}%`).total;

      const wdr = db.prepare(`
        SELECT COALESCE(SUM(amount), 0) as total
        FROM withdrawal_requests
        WHERE status = 'completed' AND created_at LIKE ?
      `).get(`${day}%`).total;

      return {
        date: day,
        deposits: dep,
        withdrawals: wdr,
        profit: Math.max(0, dep - wdr)
      };
    });

    return res.json({
      success: true,
      data: {
        totalUsers,
        onlineUsers,
        verifiedKyc,
        pendingKyc,
        totalDeposits,
        pendingDeposits,
        totalWithdrawals,
        pendingWithdrawalsCount: pendingWithdrawals.count,
        pendingWithdrawalsAmount: pendingWithdrawals.total,
        totalArenas,
        liveArenas,
        completedArenas,
        walletBalances,
        aviatorRoundsCount,
        totalBetsCount: totalBetsPlaced.count,
        totalBetsAmount: totalBetsPlaced.totalAmount,
        recentTxns,
        dailyStats,
        netRevenue: totalDeposits - totalWithdrawals
      }
    });
  } catch (error) {
    console.error('getStats error:', error);
    return res.status(500).json({ success: false, error: 'Failed to retrieve admin stats' });
  }
};

// GET /api/admin/users
exports.getUsers = (req, res) => {
  try {
    const { search, kyc, online } = req.query;
    let query = `
      SELECT u.*, w.deposit_balance, w.winning_balance, w.bonus_balance
      FROM users u
      LEFT JOIN wallets w ON u.id = w.user_id
    `;
    const params = [];
    const conditions = [];

    if (search) {
      conditions.push('(u.username LIKE ? OR u.full_name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
    }

    if (kyc) {
      conditions.push('u.kyc_status = ?');
      params.push(kyc);
    }

    if (online === 'true') {
      const fifteenSecAgo = new Date(Date.now() - 15 * 1000).toISOString();
      conditions.push('u.last_seen_at >= ?');
      params.push(fifteenSecAgo);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY u.joined_at DESC';

    const users = db.prepare(query).all(...params);
    const nowMs = Date.now();

    return res.json({
      success: true,
      data: users.map(u => {
        const lastSeenMs = u.last_seen_at ? new Date(u.last_seen_at).getTime() : 0;
        const diffSec = lastSeenMs > 0 ? Math.max(0, Math.floor((nowMs - lastSeenMs) / 1000)) : null;
        const isOnline = diffSec !== null && diffSec <= 15;

        return {
          ...formatUser(u),
          isOnline,
          lastSeenAt: u.last_seen_at,
          lastSeenSecondsAgo: diffSec,
          wallet: {
            depositBalance: u.deposit_balance || 0,
            winningBalance: u.winning_balance || 0,
            bonusBalance: u.bonus_balance || 0,
            totalBalance: (u.deposit_balance || 0) + (u.winning_balance || 0) + (u.bonus_balance || 0)
          }
        };
      })
    });
  } catch (error) {
    console.error('getUsers error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch users' });
  }
};

// POST /api/admin/users - Add New User
exports.addUser = (req, res) => {
  try {
    const { username, fullName, email, phone, password, depositBalance, winningBalance, bonusBalance, kycStatus } = req.body;

    if (!username || !fullName || !email || !phone) {
      return res.status(400).json({ success: false, error: 'Username, Full Name, Email, and Phone are required' });
    }

    const uTrim = String(username).trim();
    const fTrim = String(fullName).trim();
    const eTrim = String(email).trim();
    const pTrim = String(phone).trim();

    // Check duplicate
    const existing = db.prepare('SELECT id, username, email, phone FROM users WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR phone = ?').get(uTrim, eTrim, pTrim);
    if (existing) {
      if (existing.username && existing.username.toLowerCase() === uTrim.toLowerCase()) {
        return res.status(400).json({ success: false, error: `Username "${uTrim}" is already in use. Please choose another.` });
      }
      if (existing.email && existing.email.toLowerCase() === eTrim.toLowerCase()) {
        return res.status(400).json({ success: false, error: `Email "${eTrim}" is already registered.` });
      }
      return res.status(400).json({ success: false, error: `Phone number "${pTrim}" is already registered.` });
    }

    const userId = `usr_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    const pass = password ? bcrypt.hashSync(String(password).trim(), 10) : bcrypt.hashSync('password123', 10);
    const kyc = kycStatus || 'verified';

    db.prepare(`
      INSERT INTO users (
        id, username, full_name, email, phone, password_hash,
        avatar_seed, kyc_status, game_ids, joined_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(userId, uTrim, fTrim, eTrim, pTrim, pass, uTrim, kyc, '{}', now, now);

    const dep = parseInt(depositBalance, 10) || 500;
    const win = parseInt(winningBalance, 10) || 0;
    const bon = parseInt(bonusBalance, 10) || 0;

    db.prepare(`
      INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(userId, dep, win, bon, now);

    // Initial transaction log
    if (dep > 0) {
      db.prepare(`
        INSERT INTO transactions (id, user_id, type, amount, status, title, description, timestamp, payment_method)
        VALUES (?, ?, 'deposit', ?, 'completed', 'Admin Welcome Credit', 'Account credited by Admin', ?, 'Admin Panel')
      `).run(`txn_${Date.now()}`, userId, dep, now);
    }

    const created = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    return res.json({
      success: true,
      message: `User ${uTrim} created successfully!`,
      data: formatUser(created)
    });
  } catch (error) {
    console.error('addUser error:', error);
    return res.status(500).json({ success: false, error: error.message || 'Failed to create user' });
  }
};

// PUT /api/admin/users/:userId - Edit User & Adjust Wallet Balance
exports.updateUser = (req, res) => {
  try {
    const { userId } = req.params;
    const { fullName, username, email, phone, kycStatus, depositBalance, winningBalance, bonusBalance, password } = req.body;

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    const now = new Date().toISOString();

    const uName = username !== undefined ? username : user.username;
    const fName = fullName !== undefined ? fullName : user.full_name;
    const mail = email !== undefined ? email : user.email;
    const ph = phone !== undefined ? phone : user.phone;
    const kyc = kycStatus !== undefined ? kycStatus : user.kyc_status;

    let passHash = user.password_hash;
    if (password && password.trim().length > 0) {
      passHash = bcrypt.hashSync(password, 10);
    }

    db.prepare(`
      UPDATE users
      SET username = ?, full_name = ?, email = ?, phone = ?, kyc_status = ?, password_hash = ?, updated_at = ?
      WHERE id = ?
    `).run(uName, fName, mail, ph, kyc, passHash, now, userId);

    // Adjust Wallet balances if provided
    if (depositBalance !== undefined || winningBalance !== undefined || bonusBalance !== undefined) {
      const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      const newDep = depositBalance !== undefined ? parseInt(depositBalance, 10) : (wallet ? wallet.deposit_balance : 0);
      const newWin = winningBalance !== undefined ? parseInt(winningBalance, 10) : (wallet ? wallet.winning_balance : 0);
      const newBon = bonusBalance !== undefined ? parseInt(bonusBalance, 10) : (wallet ? wallet.bonus_balance : 0);

      db.prepare(`
        INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          deposit_balance = excluded.deposit_balance,
          winning_balance = excluded.winning_balance,
          bonus_balance = excluded.bonus_balance,
          updated_at = excluded.updated_at
      `).run(userId, newDep, newWin, newBon, now);
    }

    const updated = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    return res.json({
      success: true,
      message: 'User updated successfully',
      data: formatUser(updated)
    });
  } catch (error) {
    console.error('updateUser error:', error);
    return res.status(500).json({ success: false, error: 'Failed to update user' });
  }
};

// DELETE /api/admin/users/:userId - Delete User
exports.deleteUser = (req, res) => {
  try {
    const { userId } = req.params;
    const user = db.prepare('SELECT id, username FROM users WHERE id = ?').get(userId);
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    db.prepare('DELETE FROM users WHERE id = ?').run(userId);
    return res.json({
      success: true,
      message: `User ${user.username} deleted successfully`
    });
  } catch (error) {
    console.error('deleteUser error:', error);
    return res.status(500).json({ success: false, error: 'Failed to delete user' });
  }
};

// GET /api/admin/kyc - List KYC Verification Requests
exports.getKycList = (req, res) => {
  try {
    const { status } = req.query;
    let query = 'SELECT id, username, full_name, email, phone, kyc_status, kyc_document_type, kyc_document_number, joined_at, updated_at FROM users WHERE kyc_document_type IS NOT NULL';
    const params = [];
    if (status) {
      query += ' AND kyc_status = ?';
      params.push(status);
    }
    query += ' ORDER BY updated_at DESC';
    const list = db.prepare(query).all(...params);
    return res.json({ success: true, data: list });
  } catch (error) {
    console.error('getKycList error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch KYC records' });
  }
};

// PUT /api/admin/kyc/:userId - Approve or Reject KYC
exports.reviewKyc = (req, res) => {
  try {
    const { userId } = req.params;
    let finalStatus = req.body.status;
    if (req.body.action === 'approve' || req.body.action === 'verified') finalStatus = 'verified';
    if (req.body.action === 'reject' || req.body.action === 'rejected') finalStatus = 'rejected';
    const reason = req.body.reason;

    if (!finalStatus || !['verified', 'rejected', 'pending'].includes(finalStatus)) {
      return res.status(400).json({ success: false, error: 'Valid status is required (verified, rejected, pending)' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    const now = new Date().toISOString();
    db.prepare('UPDATE users SET kyc_status = ?, updated_at = ? WHERE id = ?').run(finalStatus, now, userId);

    // Notification
    const notifTitle = status === 'verified' ? 'KYC Verification Approved! ✅' : 'KYC Verification Rejected ❌';
    const notifMsg = status === 'verified' 
      ? 'Congratulations! Your identity document has been verified. Unlimited withdrawals unlocked.'
      : `Your KYC submission was rejected: ${reason || 'Document unreadable or invalid'}. Please re-submit valid document.`;

    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, 0)
    `).run(`notif_${Date.now()}`, userId, notifTitle, notifMsg, status === 'verified' ? 'success' : 'alert', now);

    return res.json({
      success: true,
      message: `KYC status set to ${status}`,
      kycStatus: status
    });
  } catch (error) {
    console.error('reviewKyc error:', error);
    return res.status(500).json({ success: false, error: 'Failed to review KYC' });
  }
};

// GET /api/admin/deposits
exports.getDeposits = (req, res) => {
  try {
    const { status, search } = req.query;
    let query = `
      SELECT t.*, u.username, u.full_name, u.phone
      FROM transactions t
      JOIN users u ON t.user_id = u.id
      WHERE t.type = 'deposit'
    `;
    const params = [];
    if (status) {
      query += ' AND t.status = ?';
      params.push(status);
    }
    if (search) {
      query += ' AND (t.reference_id LIKE ? OR u.username LIKE ? OR t.id LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    query += ' ORDER BY t.timestamp DESC';
    const list = db.prepare(query).all(...params);
    return res.json({ success: true, data: list });
  } catch (error) {
    console.error('getDeposits error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch deposits' });
  }
};

// POST /api/admin/deposits/manual - Credit user wallet manually
exports.manualDeposit = (req, res) => {
  try {
    const { userId, amount, title, description, balanceType } = req.body;
    const num = parseInt(amount, 10);
    if (!userId || !num || num <= 0) {
      return res.status(400).json({ success: false, error: 'Valid userId and amount are required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) return res.status(404).json({ success: false, error: 'User not found' });

    const now = new Date().toISOString();
    const type = balanceType === 'winning' ? 'winning_balance' : 'deposit_balance';

    // Ensure wallet row exists
    const walletExists = db.prepare('SELECT user_id FROM wallets WHERE user_id = ?').get(userId);
    if (!walletExists) {
      db.prepare('INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at) VALUES (?, 0, 0, 0, ?)').run(userId, now);
    }

    db.prepare(`
      UPDATE wallets
      SET ${type} = ${type} + ?, updated_at = ?
      WHERE user_id = ?
    `).run(num, now, userId);

    db.prepare(`
      INSERT INTO transactions (id, user_id, type, amount, status, title, description, timestamp, payment_method)
      VALUES (?, ?, 'deposit', ?, 'completed', ?, ?, ?, 'Admin Credit')
    `).run(
      `txn_admin_${Date.now()}`,
      userId,
      num,
      title || 'Admin Manual Credit',
      description || `Credited ₹${num} to ${balanceType || 'deposit'} wallet`,
      now
    );

    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, 'success', ?, 0)
    `).run(`notif_${Date.now()}`, userId, 'Cash Credited by Admin 💰', `₹${num} has been credited to your wallet balance.`, now);

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    return res.json({
      success: true,
      message: `₹${num} credited to ${user.username}`,
      data: formatWallet(wallet)
    });
  } catch (error) {
    console.error('manualDeposit error:', error);
    return res.status(500).json({ success: false, error: 'Failed to credit deposit' });
  }
};

// GET /api/admin/withdrawals
exports.getWithdrawals = (req, res) => {
  try {
    const { status } = req.query;

    // Auto-advance requests older than 4 hours from 'requested' to 'processing'
    const fourHoursAgo = new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString();
    db.prepare(`
      UPDATE withdrawal_requests
      SET status = 'processing'
      WHERE status = 'requested' AND created_at <= ?
    `).run(fourHoursAgo);

    let query = `
      SELECT w.*, u.username, u.full_name, u.phone, u.kyc_status, wal.winning_balance
      FROM withdrawal_requests w
      JOIN users u ON w.user_id = u.id
      JOIN wallets wal ON u.id = wal.user_id
    `;
    const params = [];
    if (status) {
      query += ' WHERE w.status = ?';
      params.push(status);
    }
    query += ' ORDER BY w.created_at DESC';
    const list = db.prepare(query).all(...params);

    // Calculate remaining hold time for 'requested' items
    const enrichedList = list.map(item => {
      const createdMs = new Date(item.created_at).getTime();
      const elapsedMs = Date.now() - createdMs;
      const fourHoursMs = 4 * 60 * 60 * 1000;
      const remainingMs = Math.max(0, fourHoursMs - elapsedMs);
      const remainingMinutes = Math.ceil(remainingMs / (60 * 1000));
      return {
        ...item,
        remainingMinutes,
        isEligibleForProcessing: remainingMs === 0 || item.status === 'processing'
      };
    });

    return res.json({ success: true, data: enrichedList });
  } catch (error) {
    console.error('getWithdrawals error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch withdrawals' });
  }
};

// PUT /api/admin/withdrawals/:id - Approve, Reject, or Fast-Track Withdrawal
exports.reviewWithdrawal = (req, res) => {
  try {
    const { id } = req.params;
    const { action, utrRef, reason } = req.body; // 'approve' | 'reject' | 'fast_track'

    const reqItem = db.prepare('SELECT * FROM withdrawal_requests WHERE id = ?').get(id);
    if (!reqItem) return res.status(404).json({ success: false, error: 'Withdrawal request not found' });

    if (['completed', 'rejected'].includes(reqItem.status)) {
      return res.status(400).json({ success: false, error: `Withdrawal is already ${reqItem.status}` });
    }

    const now = new Date().toISOString();

    if (action === 'fast_track') {
      db.prepare(`
        UPDATE withdrawal_requests
        SET status = 'processing'
        WHERE id = ?
      `).run(id);

      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, 'Withdrawal Under Processing ⏳', ?, 'info', ?, 0)
      `).run(`notif_${Date.now()}`, reqItem.user_id, `Your ₹${reqItem.amount} withdrawal has entered bank dispatch processing.`, now);

      return res.json({
        success: true,
        message: `Withdrawal fast-tracked to PROCESSING state`,
        status: 'processing'
      });
    } else if (action === 'approve') {
      const ref = utrRef || `PAY_${Date.now()}`;
      db.prepare(`
        UPDATE withdrawal_requests
        SET status = 'completed', processed_at = ?, txn_reference = ?
        WHERE id = ?
      `).run(now, ref, id);

      // Update matching transaction to completed
      db.prepare(`
        UPDATE transactions
        SET status = 'completed', reference_id = ?
        WHERE user_id = ? AND reference_id = ?
      `).run(ref, reqItem.user_id, reqItem.txn_reference);

      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, 'Withdrawal Payout Success! 💸', ?, 'success', ?, 0)
      `).run(`notif_${Date.now()}`, reqItem.user_id, `₹${reqItem.amount} has been paid out via ${reqItem.method}. Bank Ref: ${ref}`, now);

      return res.json({
        success: true,
        message: `Withdrawal of ₹${reqItem.amount} approved and settled`,
        status: 'completed',
        reference: ref
      });
    } else if (action === 'reject') {
      // Refund amount back to user winning balance
      db.prepare(`
        UPDATE wallets
        SET winning_balance = winning_balance + ?, updated_at = ?
        WHERE user_id = ?
      `).run(reqItem.amount, now, reqItem.user_id);

      db.prepare(`
        UPDATE withdrawal_requests
        SET status = 'rejected', processed_at = ?, txn_reference = ?
        WHERE id = ?
      `).run(now, reason || 'Rejected by admin', id);

      // Update matching transaction to failed/refunded
      db.prepare(`
        UPDATE transactions
        SET status = 'failed', description = ?
        WHERE user_id = ? AND reference_id = ?
      `).run(`Rejected: ${reason || 'Invalid details'}. Refunded to winnings.`, reqItem.user_id, reqItem.txn_reference);

      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, 'Withdrawal Request Rejected ❌', ?, 'alert', ?, 0)
      `).run(`notif_${Date.now()}`, reqItem.user_id, `Withdrawal of ₹${reqItem.amount} was rejected: ${reason || 'Incorrect account details'}. ₹${reqItem.amount} has been refunded to your winning balance.`, now);

      return res.json({
        success: true,
        message: `Withdrawal rejected and ₹${reqItem.amount} refunded to user winning balance`,
        status: 'rejected'
      });
    } else {
      return res.status(400).json({ success: false, error: 'Action must be approve, reject, or fast_track' });
    }
  } catch (error) {
    console.error('reviewWithdrawal error:', error);
    return res.status(500).json({ success: false, error: 'Failed to process withdrawal review' });
  }
};

// GET /api/admin/arenas
exports.getArenas = (req, res) => {
  try {
    const arenas = db.prepare('SELECT * FROM arenas ORDER BY start_time DESC').all();
    const data = arenas.map(a => {
      const participants = db.prepare('SELECT user_id, username, in_game_id, joined_at FROM arena_participants WHERE arena_id = ?').all(a.id);
      return {
        ...formatArena(a),
        registeredPlayers: participants
      };
    });
    return res.json({ success: true, data });
  } catch (error) {
    console.error('getArenas error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch tournaments' });
  }
};

// POST /api/admin/arenas - Create Tournament
exports.createArena = (req, res) => {
  try {
    const { title, game, format, map, server, entryFee, prizePool, perKillPrize, maxSlots, startTime, roomId, roomPassword, rules, prizeDistribution } = req.body;

    if (!title || !game) {
      return res.status(400).json({ success: false, error: 'Title and Game are required' });
    }

    const arenaId = `arn_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO arenas (
        id, title, game, format, map, server, entry_fee, prize_pool,
        per_kill_prize, max_slots, start_time, status, room_id, room_password,
        rules, prize_distribution, created_by, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'upcoming', ?, ?, ?, ?, 'admin', ?)
    `).run(
      arenaId,
      title,
      game,
      format || 'Squad',
      map || 'Classic',
      server || 'Asia',
      parseInt(entryFee, 10) || 0,
      parseInt(prizePool, 10) || 0,
      parseInt(perKillPrize, 10) || 0,
      parseInt(maxSlots, 10) || 100,
      startTime || new Date(Date.now() + 3600000).toISOString(),
      roomId || null,
      roomPassword || null,
      JSON.stringify(rules || ['Fair play only', 'No hacks/emulators']),
      JSON.stringify(prizeDistribution || [{ rank: 1, prize: prizePool || 0 }]),
      now
    );

    const created = db.prepare('SELECT * FROM arenas WHERE id = ?').get(arenaId);
    return res.json({
      success: true,
      message: 'Tournament created successfully',
      data: formatArena(created)
    });
  } catch (error) {
    console.error('createArena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to create arena' });
  }
};

// PUT /api/admin/arenas/:id - Update Tournament Details & Credentials
exports.updateArena = (req, res) => {
  try {
    const { id } = req.params;
    const { title, status, roomId, roomPassword, winner } = req.body;

    const arena = db.prepare('SELECT * FROM arenas WHERE id = ?').get(id);
    if (!arena) return res.status(404).json({ success: false, error: 'Arena not found' });

    const newTitle = title !== undefined ? title : arena.title;
    const newStatus = status !== undefined ? status : arena.status;
    const newRoomId = roomId !== undefined ? roomId : arena.room_id;
    const newRoomPass = roomPassword !== undefined ? roomPassword : arena.room_password;
    const newWinner = winner !== undefined ? winner : arena.winner;

    db.prepare(`
      UPDATE arenas
      SET title = ?, status = ?, room_id = ?, room_password = ?, winner = ?
      WHERE id = ?
    `).run(newTitle, newStatus, newRoomId, newRoomPass, newWinner, id);

    // If room credentials were just updated and published, notify joined participants
    if (newRoomId && (newRoomId !== arena.room_id || newRoomPass !== arena.room_password)) {
      const participants = db.prepare('SELECT user_id FROM arena_participants WHERE arena_id = ?').all(id);
      const now = new Date().toISOString();
      for (const p of participants) {
        db.prepare(`
          INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
          VALUES (?, ?, 'Room ID & Password Live! 🔑', ?, 'info', ?, 0)
        `).run(`notif_${Date.now()}_${p.user_id}`, p.user_id, `Match credentials for "${newTitle}" are: Room: ${newRoomId} | Pass: ${newRoomPass}`, now);
      }
    }

    const updated = db.prepare('SELECT * FROM arenas WHERE id = ?').get(id);
    return res.json({
      success: true,
      message: 'Tournament updated successfully',
      data: formatArena(updated)
    });
  } catch (error) {
    console.error('updateArena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to update arena' });
  }
};

// DELETE /api/admin/arenas/:id - Delete Tournament
exports.deleteArena = (req, res) => {
  try {
    const { id } = req.params;
    const arena = db.prepare('SELECT id, title FROM arenas WHERE id = ?').get(id);
    if (!arena) return res.status(404).json({ success: false, error: 'Arena not found' });

    db.prepare('DELETE FROM arenas WHERE id = ?').run(id);
    return res.json({ success: true, message: `Tournament "${arena.title}" deleted successfully` });
  } catch (error) {
    console.error('deleteArena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to delete arena' });
  }
};

// GET /api/admin/aviator - Cockpit state & Controls
exports.getAviatorCockpit = (req, res) => {
  try {
    const state = aviatorEngine.getGameState('admin');
    const recentRounds = db.prepare(`
      SELECT * FROM game_rounds
      WHERE game_type = 'aviator'
      ORDER BY created_at DESC
      LIMIT 20
    `).all();

    return res.json({
      success: true,
      data: {
        currentState: state.state,
        currentMultiplier: state.currentMultiplier,
        targetCrashMultiplier: aviatorEngine.targetCrashMultiplier,
        forcedTarget: aviatorEngine.forcedTarget || null,
        activeBets: Array.from(aviatorEngine.activeBets.values()),
        history: aviatorEngine.history,
        recentDbRounds: recentRounds
      }
    });
  } catch (error) {
    console.error('getAviatorCockpit error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch Aviator cockpit' });
  }
};

// POST /api/admin/aviator/control - Set next multiplier / Force Crash
exports.controlAviator = (req, res) => {
  try {
    const { action, targetMultiplier } = req.body;

    if (action === 'set_target') {
      const target = parseFloat(targetMultiplier);
      if (!target || target < 1.0) {
        return res.status(400).json({ success: false, error: 'Target multiplier must be >= 1.00' });
      }
      aviatorEngine.forcedTarget = Math.round(target * 100) / 100;
      aviatorEngine.targetCrashMultiplier = aviatorEngine.forcedTarget;

      return res.json({
        success: true,
        message: `Target crash multiplier overridden to ${aviatorEngine.forcedTarget}x`,
        forcedTarget: aviatorEngine.forcedTarget
      });
    } else if (action === 'force_crash') {
      if (aviatorEngine.state === 'flying') {
        aviatorEngine.targetCrashMultiplier = aviatorEngine.currentMultiplier;
        return res.json({
          success: true,
          message: `Plane forced to crash immediately at ${aviatorEngine.currentMultiplier.toFixed(2)}x`
        });
      } else {
        return res.status(400).json({ success: false, error: `Plane is currently in "${aviatorEngine.state}" state` });
      }
    } else if (action === 'reset_fair') {
      aviatorEngine.forcedTarget = null;
      return res.json({
        success: true,
        message: 'Aviator algorithm reset to provably fair random distribution'
      });
    }

    return res.status(400).json({ success: false, error: 'Invalid action' });
  } catch (error) {
    console.error('controlAviator error:', error);
    return res.status(500).json({ success: false, error: 'Failed to control Aviator engine' });
  }
};

// GET /api/admin/settings
exports.getSettings = (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM system_settings').all();
    const settings = {};
    for (const r of rows) {
      settings[r.key] = r.value;
    }
    return res.json({
      success: true,
      data: {
        minDeposit: parseInt(settings.min_deposit || '50', 10),
        minWithdrawal: parseInt(settings.min_withdrawal || '50', 10),
        maxDeposit: parseInt(settings.max_deposit || '50000', 10),
        maxWithdrawal: parseInt(settings.max_withdrawal || '100000', 10),
        razorpayEnabled: settings.razorpay_enabled !== 'false',
        razorpayKeyId: settings.razorpay_key_id || 'rzp_test_YOUR_KEY_ID',
        razorpayKeySecret: settings.razorpay_key_secret || '',
        razorpayWebhookSecret: settings.razorpay_webhook_secret || '',
        razorpayMode: settings.razorpay_mode || 'test'
      }
    });
  } catch (error) {
    console.error('getSettings error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch settings' });
  }
};

// PUT /api/admin/settings
exports.updateSettings = (req, res) => {
  try {
    const {
      minDeposit,
      minWithdrawal,
      maxDeposit,
      maxWithdrawal,
      razorpayEnabled,
      razorpayKeyId,
      razorpayKeySecret,
      razorpayWebhookSecret,
      razorpayMode
    } = req.body;
    const now = new Date().toISOString();

    const upsert = db.prepare(`
      INSERT INTO system_settings (key, value, description, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
    `);

    if (minDeposit !== undefined) {
      const val = parseInt(minDeposit, 10);
      if (isNaN(val) || val < 1) return res.status(400).json({ success: false, error: 'Minimum deposit must be at least ₹1' });
      upsert.run('min_deposit', String(val), 'Minimum deposit amount in INR', now);
    }

    if (minWithdrawal !== undefined) {
      const val = parseInt(minWithdrawal, 10);
      if (isNaN(val) || val < 1) return res.status(400).json({ success: false, error: 'Minimum withdrawal must be at least ₹1' });
      upsert.run('min_withdrawal', String(val), 'Minimum withdrawal amount in INR', now);
    }

    if (maxDeposit !== undefined) {
      const val = parseInt(maxDeposit, 10);
      if (isNaN(val) || val < 100) return res.status(400).json({ success: false, error: 'Maximum deposit must be at least ₹100' });
      upsert.run('max_deposit', String(val), 'Maximum single deposit amount in INR', now);
    }

    if (maxWithdrawal !== undefined) {
      const val = parseInt(maxWithdrawal, 10);
      if (isNaN(val) || val < 100) return res.status(400).json({ success: false, error: 'Maximum withdrawal must be at least ₹100' });
      upsert.run('max_withdrawal', String(val), 'Maximum single withdrawal amount in INR', now);
    }

    if (razorpayEnabled !== undefined) {
      upsert.run('razorpay_enabled', razorpayEnabled ? 'true' : 'false', 'Enable or disable Razorpay gateway', now);
    }

    if (razorpayKeyId !== undefined) {
      upsert.run('razorpay_key_id', String(razorpayKeyId).trim(), 'Razorpay API Key ID', now);
    }

    if (razorpayKeySecret !== undefined) {
      upsert.run('razorpay_key_secret', String(razorpayKeySecret).trim(), 'Razorpay API Key Secret', now);
    }

    if (razorpayWebhookSecret !== undefined) {
      upsert.run('razorpay_webhook_secret', String(razorpayWebhookSecret).trim(), 'Razorpay Webhook Secret', now);
    }

    if (razorpayMode !== undefined) {
      upsert.run('razorpay_mode', razorpayMode === 'live' ? 'live' : 'test', 'Razorpay environment mode', now);
    }

    const rows = db.prepare('SELECT * FROM system_settings').all();
    const settings = {};
    for (const r of rows) settings[r.key] = r.value;

    return res.json({
      success: true,
      message: 'Platform settings & Razorpay configuration saved successfully',
      data: {
        minDeposit: parseInt(settings.min_deposit || '50', 10),
        minWithdrawal: parseInt(settings.min_withdrawal || '50', 10),
        maxDeposit: parseInt(settings.max_deposit || '50000', 10),
        maxWithdrawal: parseInt(settings.max_withdrawal || '100000', 10),
        razorpayEnabled: settings.razorpay_enabled !== 'false',
        razorpayKeyId: settings.razorpay_key_id || 'rzp_test_YOUR_KEY_ID',
        razorpayKeySecret: settings.razorpay_key_secret || '',
        razorpayWebhookSecret: settings.razorpay_webhook_secret || '',
        razorpayMode: settings.razorpay_mode || 'test'
      }
    });
  } catch (error) {
    console.error('updateSettings error:', error);
    return res.status(500).json({ success: false, error: 'Failed to update settings' });
  }
};
