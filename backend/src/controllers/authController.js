const bcrypt = require('bcryptjs');
const { db } = require('../config/database');
const { formatUser } = require('../utils/helpers');

exports.login = (req, res) => {
  try {
    const { identifier, password } = req.body;
    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        error: 'Identifier (username/email/phone) and password are required'
      });
    }

    const trimmed = identifier.trim();
    const userRow = db.prepare(`
      SELECT * FROM users
      WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR phone = ?
    `).get(trimmed, trimmed, trimmed);

    if (!userRow) {
      return res.status(401).json({
        success: false,
        error: 'No account found with this username, email, or phone.'
      });
    }

    if (userRow.password_hash) {
      const isValid = bcrypt.compareSync(password, userRow.password_hash);
      if (!isValid) {
        return res.status(401).json({
          success: false,
          error: 'Incorrect password. Please try again.'
        });
      }
    }

    return res.json({
      success: true,
      message: 'Login successful',
      data: formatUser(userRow)
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({
      success: false,
      error: 'An internal server error occurred during login.'
    });
  }
};

exports.register = (req, res) => {
  try {
    const { username, fullName, email, phone, password } = req.body;
    if (!username || !fullName || !email || !phone || !password) {
      return res.status(400).json({
        success: false,
        error: 'All fields (username, full name, email, phone, password) are required.'
      });
    }

    // Check for existing user
    const existing = db.prepare(`
      SELECT * FROM users
      WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR phone = ?
    `).get(username.trim(), email.trim(), phone.trim());

    if (existing) {
      if (existing.username.toLowerCase() === username.trim().toLowerCase()) {
        return res.status(400).json({ success: false, error: 'Username is already taken.' });
      }
      if (existing.email.toLowerCase() === email.trim().toLowerCase()) {
        return res.status(400).json({ success: false, error: 'Email is already registered.' });
      }
      return res.status(400).json({ success: false, error: 'Phone number is already registered.' });
    }

    const userId = `usr_${Date.now()}`;
    const now = new Date().toISOString();
    const passwordHash = bcrypt.hashSync(password, 10);

    const insertUser = db.prepare(`
      INSERT INTO users (
        id, username, full_name, email, phone, password_hash,
        avatar_seed, kyc_status, joined_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    insertUser.run(
      userId,
      username.trim(),
      fullName.trim(),
      email.trim(),
      phone.trim(),
      passwordHash,
      username.trim(),
      'not_submitted',
      now,
      now
    );

    // Create wallet with ₹100 welcome bonus
    const insertWallet = db.prepare(`
      INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `);
    insertWallet.run(userId, 0, 0, 100, now);

    // Add bonus transaction
    const insertTxn = db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    insertTxn.run(
      `TXN_BONUS_${Date.now()}`,
      userId,
      'bonus',
      100,
      'completed',
      'Signup Welcome Bonus',
      '₹100 Free bonus cash added to your wallet',
      now,
      `REF_SIGNUP_${Date.now()}`,
      'Registration'
    );

    // Add welcome notification
    const insertNotif = db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);
    insertNotif.run(
      `notif_${Date.now()}`,
      userId,
      'Welcome to Tournament Arena!',
      'Your account was created with a ₹100 welcome bonus.',
      'success',
      now,
      0
    );

    const newUserRow = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    return res.status(200).json({
      success: true,
      message: 'Registration successful! Welcome bonus added.',
      data: formatUser(newUserRow)
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({
      success: false,
      error: 'Registration failed due to an internal error.'
    });
  }
};

exports.forgotPassword = (req, res) => {
  try {
    const { identifier } = req.body;
    if (!identifier) {
      return res.status(400).json({ success: false, error: 'Identifier is required.' });
    }

    const trimmed = identifier.trim();
    const userRow = db.prepare(`
      SELECT * FROM users
      WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR phone = ?
    `).get(trimmed, trimmed, trimmed);

    if (!userRow) {
      return res.status(404).json({ success: false, error: 'No user found with provided identifier.' });
    }

    const generatedOtp = String(Math.floor(100000 + Math.random() * 900000));
    db.prepare('UPDATE users SET reset_otp = ? WHERE id = ?').run(generatedOtp, userRow.id);

    return res.json({
      success: true,
      message: 'Verification OTP has been sent.',
      data: {
        resetOtp: generatedOtp
      }
    });
  } catch (error) {
    console.error('Forgot password error:', error);
    return res.status(500).json({ success: false, error: 'Failed to process forgot password request.' });
  }
};

exports.resetPassword = (req, res) => {
  try {
    const { identifier, otp, newPassword } = req.body;
    if (!identifier || !otp || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'Identifier, OTP, and new password are required.'
      });
    }

    const trimmed = identifier.trim();
    const userRow = db.prepare(`
      SELECT * FROM users
      WHERE LOWER(username) = LOWER(?) OR LOWER(email) = LOWER(?) OR phone = ?
    `).get(trimmed, trimmed, trimmed);

    if (!userRow) {
      return res.status(404).json({ success: false, error: 'Account not found.' });
    }

    if (userRow.reset_otp !== otp) {
      return res.status(400).json({ success: false, error: 'Invalid verification OTP code.' });
    }

    const newHash = bcrypt.hashSync(newPassword, 10);
    const now = new Date().toISOString();
    db.prepare('UPDATE users SET password_hash = ?, reset_otp = NULL, updated_at = ? WHERE id = ?')
      .run(newHash, now, userRow.id);

    return res.json({
      success: true,
      message: 'Password reset successfully. You can now login with your new password.'
    });
  } catch (error) {
    console.error('Reset password error:', error);
    return res.status(500).json({ success: false, error: 'Failed to reset password.' });
  }
};
