const { db } = require('../config/database');
const { formatUser } = require('../utils/helpers');

exports.updateProfile = (req, res) => {
  try {
    const { userId } = req.params;
    const { fullName, username, email, phone } = req.body;

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    const updatedFullName = fullName !== undefined ? fullName : user.full_name;
    const updatedUsername = username !== undefined ? username : user.username;
    const updatedEmail = email !== undefined ? email : user.email;
    const updatedPhone = phone !== undefined ? phone : user.phone;
    const now = new Date().toISOString();

    db.prepare(`
      UPDATE users
      SET full_name = ?, username = ?, email = ?, phone = ?, updated_at = ?
      WHERE id = ?
    `).run(updatedFullName, updatedUsername, updatedEmail, updatedPhone, now, userId);

    const updatedUser = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    return res.json({
      success: true,
      message: 'Profile updated successfully',
      data: formatUser(updatedUser)
    });
  } catch (error) {
    console.error('Update profile error:', error);
    return res.status(500).json({ success: false, error: 'Failed to update profile' });
  }
};

exports.submitKyc = (req, res) => {
  try {
    const { userId } = req.params;
    const docType = req.body.docType || req.body.documentType;
    const docNumber = req.body.docNumber || req.body.documentNumber;

    if (!docType || !docNumber) {
      return res.status(400).json({ success: false, error: 'Document type and number are required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE users
      SET kyc_status = 'pending', kyc_document_type = ?, kyc_document_number = ?, updated_at = ?
      WHERE id = ?
    `).run(docType, docNumber, now, userId);

    // Create notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_kyc_${Date.now()}`,
      userId,
      'KYC Under Verification ⏳',
      `Your ${docType} (${docNumber}) has been submitted and is currently being verified by admin.`,
      'info',
      now,
      0
    );

    const updatedUser = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    return res.json({
      success: true,
      message: 'KYC submitted successfully and is pending admin approval',
      data: formatUser(updatedUser)
    });
  } catch (error) {
    console.error('Submit KYC error:', error);
    return res.status(500).json({ success: false, error: 'Failed to process KYC submission' });
  }
};

exports.saveGameId = (req, res) => {
  try {
    const { userId } = req.params;
    const { gameKey, inGameId } = req.body;

    if (!gameKey || !inGameId) {
      return res.status(400).json({ success: false, error: 'Game key and inGameId are required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    let gameIds = {};
    try {
      gameIds = typeof user.game_ids === 'string' ? JSON.parse(user.game_ids) : (user.game_ids || {});
    } catch (_) {
      gameIds = {};
    }

    gameIds[gameKey] = inGameId;
    const now = new Date().toISOString();

    db.prepare(`
      UPDATE users
      SET game_ids = ?, updated_at = ?
      WHERE id = ?
    `).run(JSON.stringify(gameIds), now, userId);

    const updatedUser = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    return res.json({
      success: true,
      message: `In-game ID for ${gameKey} saved`,
      data: formatUser(updatedUser)
    });
  } catch (error) {
    console.error('Save game ID error:', error);
    return res.status(500).json({ success: false, error: 'Failed to save in-game ID' });
  }
};

exports.savePayoutMethod = (req, res) => {
  try {
    const { userId } = req.params;
    const { type, data } = req.body;

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    const now = new Date().toISOString();

    if (type === 'upi') {
      db.prepare('UPDATE users SET upi_id = ?, updated_at = ? WHERE id = ?')
        .run(typeof data === 'string' ? data : String(data), now, userId);
    } else if (type === 'bank') {
      const bankDataStr = typeof data === 'string' ? data : JSON.stringify(data);
      db.prepare('UPDATE users SET bank_account = ?, updated_at = ? WHERE id = ?')
        .run(bankDataStr, now, userId);
    }

    const updatedUser = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    return res.json({
      success: true,
      message: 'Payout method saved successfully',
      data: formatUser(updatedUser)
    });
  } catch (error) {
    console.error('Save payout method error:', error);
    return res.status(500).json({ success: false, error: 'Failed to save payout method' });
  }
};

const bcrypt = require('bcryptjs');

exports.changePassword = (req, res) => {
  try {
    const { userId } = req.params;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, error: 'Current password and new password are required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    if (user.password_hash) {
      const isValid = bcrypt.compareSync(currentPassword, user.password_hash);
      if (!isValid) {
        return res.status(400).json({ success: false, error: 'Current password does not match.' });
      }
    }

    const newHash = bcrypt.hashSync(newPassword, 10);
    const now = new Date().toISOString();

    db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?')
      .run(newHash, now, userId);

    return res.json({
      success: true,
      message: 'Password changed successfully.'
    });
  } catch (error) {
    console.error('Change password error:', error);
    return res.status(500).json({ success: false, error: 'Failed to change password' });
  }
};

exports.resetAccount = (req, res) => {
  try {
    const { userId } = req.params;
    const now = new Date().toISOString();

    // Reset wallet to default starting amount
    db.prepare(`
      UPDATE wallets
      SET deposit_balance = 500, winning_balance = 250, bonus_balance = 100, updated_at = ?
      WHERE user_id = ?
    `).run(now, userId);

    // Clear user participants, transactions, withdrawals, and notifications for this user
    db.prepare('DELETE FROM arena_participants WHERE user_id = ?').run(userId);
    db.prepare('DELETE FROM transactions WHERE user_id = ?').run(userId);
    db.prepare('DELETE FROM withdrawal_requests WHERE user_id = ?').run(userId);
    db.prepare('DELETE FROM notifications WHERE user_id = ?').run(userId);
    db.prepare('DELETE FROM game_bets WHERE user_id = ?').run(userId);

    // Insert welcome transaction and notification
    db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      `TXN_RESET_${Date.now()}`,
      userId,
      'bonus',
      100,
      'completed',
      'Account Reset Complete',
      'Wallet balances re-initialized to initial demo values',
      now,
      'REF_RESET',
      'System'
    );

    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_reset_${Date.now()}`,
      userId,
      'Account Reset',
      'Your account data, matches, and transactions have been reset to clean defaults.',
      'info',
      now,
      0
    );

    return res.json({
      success: true,
      message: 'Account state reset to clean defaults.'
    });
  } catch (error) {
    console.error('Reset account error:', error);
    return res.status(500).json({ success: false, error: 'Failed to reset account' });
  }
};

exports.heartbeat = (req, res) => {
  try {
    const { userId } = req.params;
    const now = new Date().toISOString();
    db.prepare('UPDATE users SET last_seen_at = ? WHERE id = ?').run(now, userId);
    return res.json({ success: true, timestamp: now, online: true });
  } catch (error) {
    return res.status(500).json({ success: false, error: 'Heartbeat failed' });
  }
};
