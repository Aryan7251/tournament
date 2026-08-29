const { DatabaseSync } = require('node:sqlite');
const path = require('path');
const fs = require('fs');
const bcrypt = require('bcryptjs');

// Ensure data directory exists
const dataDir = path.join(__dirname, '..', '..', 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'tournament.db');
const db = new DatabaseSync(dbPath);

// Enable foreign keys and WAL mode for better concurrency
db.exec('PRAGMA foreign_keys = ON;');
db.exec('PRAGMA journal_mode = WAL;');

function initDatabase() {
  // 1. Users table
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      full_name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      phone TEXT UNIQUE NOT NULL,
      password_hash TEXT,
      avatar_seed TEXT,
      kyc_status TEXT DEFAULT 'not_submitted',
      kyc_document_type TEXT,
      kyc_document_number TEXT,
      game_ids TEXT DEFAULT '{}',
      upi_id TEXT,
      bank_account TEXT,
      reset_otp TEXT,
      joined_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_seen_at TEXT
    );
  `);

  try {
    db.exec('ALTER TABLE users ADD COLUMN last_seen_at TEXT;');
  } catch (_) {
    // Column already exists
  }

  // 2. Wallets table
  db.exec(`
    CREATE TABLE IF NOT EXISTS wallets (
      user_id TEXT PRIMARY KEY,
      deposit_balance INTEGER DEFAULT 0,
      winning_balance INTEGER DEFAULT 0,
      bonus_balance INTEGER DEFAULT 0,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  // 3. Arenas (Tournaments) table
  db.exec(`
    CREATE TABLE IF NOT EXISTS arenas (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      game TEXT NOT NULL,
      format TEXT NOT NULL,
      map TEXT NOT NULL,
      server TEXT NOT NULL,
      entry_fee INTEGER NOT NULL DEFAULT 0,
      prize_pool INTEGER NOT NULL DEFAULT 0,
      per_kill_prize INTEGER NOT NULL DEFAULT 0,
      max_slots INTEGER NOT NULL DEFAULT 100,
      start_time TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'upcoming',
      room_id TEXT,
      room_password TEXT,
      rules TEXT DEFAULT '[]',
      prize_distribution TEXT DEFAULT '[]',
      winner TEXT,
      created_by TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  `);

  // 4. Arena Participants table
  db.exec(`
    CREATE TABLE IF NOT EXISTS arena_participants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      arena_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      username TEXT NOT NULL,
      in_game_id TEXT NOT NULL,
      joined_at TEXT NOT NULL,
      FOREIGN KEY (arena_id) REFERENCES arenas(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(arena_id, user_id)
    );
  `);

  // 5. Transactions table
  db.exec(`
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'completed',
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      timestamp TEXT NOT NULL,
      reference_id TEXT,
      payment_method TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  // 6. Withdrawal Requests table
  db.exec(`
    CREATE TABLE IF NOT EXISTS withdrawal_requests (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount INTEGER NOT NULL,
      method TEXT NOT NULL,
      account_details TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'completed',
      created_at TEXT NOT NULL,
      processed_at TEXT,
      txn_reference TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  // 7. Notifications table
  db.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'info',
      timestamp TEXT NOT NULL,
      read INTEGER DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  // 8. Game Rounds table (Provably Fair Game Engine)
  db.exec(`
    CREATE TABLE IF NOT EXISTS game_rounds (
      id TEXT PRIMARY KEY,
      game_type TEXT NOT NULL,
      crash_multiplier REAL NOT NULL,
      server_seed TEXT NOT NULL,
      hash TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'completed',
      created_at TEXT NOT NULL,
      crashed_at TEXT
    );
  `);

  // 9. Game Bets table
  db.exec(`
    CREATE TABLE IF NOT EXISTS game_bets (
      id TEXT PRIMARY KEY,
      round_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      slot_num INTEGER NOT NULL DEFAULT 1,
      amount INTEGER NOT NULL,
      auto_cashout_enabled INTEGER DEFAULT 0,
      auto_cashout_value REAL DEFAULT 2.0,
      status TEXT NOT NULL DEFAULT 'placed',
      cashout_multiplier REAL,
      won_amount INTEGER DEFAULT 0,
      placed_at TEXT NOT NULL,
      cashed_out_at TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  // 10. System Settings table (Financial Limits & Dynamic Rules)
  db.exec(`
    CREATE TABLE IF NOT EXISTS system_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      description TEXT,
      updated_at TEXT NOT NULL
    );
  `);

  // Seed default settings if not exists
  seedSystemSettings();

  // Seed default data if users table is empty
  seedDatabase();
}

function seedSystemSettings() {
  const now = new Date().toISOString();
  const defaults = [
    { key: 'min_deposit', value: '50', description: 'Minimum deposit amount in INR' },
    { key: 'min_withdrawal', value: '50', description: 'Minimum withdrawal amount in INR' },
    { key: 'max_deposit', value: '50000', description: 'Maximum single deposit amount in INR' },
    { key: 'max_withdrawal', value: '100000', description: 'Maximum single withdrawal amount in INR' },
    { key: 'razorpay_enabled', value: 'true', description: 'Enable or disable Razorpay payment gateway' },
    { key: 'razorpay_key_id', value: 'rzp_test_YOUR_KEY_ID', description: 'Razorpay API Key ID' },
    { key: 'razorpay_key_secret', value: '', description: 'Razorpay API Key Secret' },
    { key: 'razorpay_webhook_secret', value: '', description: 'Razorpay Webhook Secret' },
    { key: 'razorpay_mode', value: 'test', description: 'Razorpay environment mode (test or live)' }
  ];

  const insertSetting = db.prepare(`
    INSERT OR IGNORE INTO system_settings (key, value, description, updated_at)
    VALUES (?, ?, ?, ?)
  `);

  for (const s of defaults) {
    insertSetting.run(s.key, s.value, s.description, now);
  }
}

function seedDatabase() {
  const checkUser = db.prepare('SELECT COUNT(*) as count FROM users').get();
  if (checkUser.count === 0) {
    console.log('Seeding initial tournament database...');

    const defaultUserId = 'usr_default_player1';
    const now = new Date().toISOString();
    const defaultPasswordHash = bcrypt.hashSync('password123', 10);

    // 1. Default User
    const insertUser = db.prepare(`
      INSERT INTO users (
        id, username, full_name, email, phone, password_hash,
        avatar_seed, kyc_status, kyc_document_type, kyc_document_number,
        game_ids, upi_id, bank_account, joined_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    insertUser.run(
      defaultUserId,
      'Player1',
      'Player Account',
      'player1@gamingarena.com',
      '+91 9876543210',
      defaultPasswordHash,
      'Player1',
      'not_submitted',
      null,
      null,
      '{}',
      'player1@okhdfcbank',
      JSON.stringify({
        accountNumber: '919876543210',
        ifscCode: 'HDFC0001234',
        accountHolder: 'Player Account',
        bankName: 'HDFC Bank'
      }),
      now,
      now
    );

    // 2. Default Wallet
    const insertWallet = db.prepare(`
      INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `);
    insertWallet.run(defaultUserId, 500, 250, 100, now);

    // 3. No initial games seeded (clean empty state)

    // 4. Initial Transactions
    const insertTxn = db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    insertTxn.run(
      'TXN_WELCOME_BONUS',
      defaultUserId,
      'bonus',
      100,
      'completed',
      'Welcome Signup Bonus',
      'Bonus cash added on registration',
      now,
      'REF_INIT_001',
      'Promotion'
    );

    insertTxn.run(
      'TXN_INIT_DEP',
      defaultUserId,
      'deposit',
      500,
      'completed',
      'Initial Wallet Deposit',
      'Added funds via UPI',
      now,
      'REF_INIT_002',
      'UPI Transfer'
    );

    // 5. Initial Notifications
    const insertNotif = db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    insertNotif.run(
      'notif_welcome_01',
      defaultUserId,
      'Welcome to Tournament Arena!',
      'Your account is ready. Explore upcoming arenas, register, and win real cash rewards.',
      'info',
      now,
      0
    );

    console.log('Database successfully initialized and seeded.');
  }
}

module.exports = {
  db,
  initDatabase
};
