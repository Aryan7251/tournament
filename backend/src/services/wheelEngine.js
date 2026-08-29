const crypto = require('crypto');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

const WHEEL_PRESETS = {
  medium: [
    { index: 0, multiplier: 0.0, label: '0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 1, multiplier: 1.5, label: '1.5x', color: '#3867D6', textColor: '#FFFFFF' },
    { index: 2, multiplier: 2.0, label: '2.0x', color: '#20BF6B', textColor: '#FFFFFF' },
    { index: 3, multiplier: 0.5, label: '0.5x', color: '#8854D0', textColor: '#FFFFFF' },
    { index: 4, multiplier: 3.0, label: '3.0x', color: '#FA8231', textColor: '#FFFFFF' },
    { index: 5, multiplier: 1.2, label: '1.2x', color: '#0FB9B1', textColor: '#FFFFFF' },
    { index: 6, multiplier: 5.0, label: '5.0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 7, multiplier: 0.0, label: '0x', color: '#4B6584', textColor: '#FFFFFF' },
    { index: 8, multiplier: 2.5, label: '2.5x', color: '#20BF6B', textColor: '#FFFFFF' },
    { index: 9, multiplier: 10.0, label: '10x', color: '#FA8231', textColor: '#FFFFFF' },
    { index: 10, multiplier: 0.0, label: '0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 11, multiplier: 25.0, label: '25x 👑', color: '#FFD32A', textColor: '#000000' }
  ],
  low: [
    { index: 0, multiplier: 1.2, label: '1.2x', color: '#0FB9B1', textColor: '#FFFFFF' },
    { index: 1, multiplier: 1.5, label: '1.5x', color: '#3867D6', textColor: '#FFFFFF' },
    { index: 2, multiplier: 0.8, label: '0.8x', color: '#8854D0', textColor: '#FFFFFF' },
    { index: 3, multiplier: 1.2, label: '1.2x', color: '#0FB9B1', textColor: '#FFFFFF' },
    { index: 4, multiplier: 2.0, label: '2.0x', color: '#20BF6B', textColor: '#FFFFFF' },
    { index: 5, multiplier: 1.5, label: '1.5x', color: '#3867D6', textColor: '#FFFFFF' },
    { index: 6, multiplier: 1.0, label: '1.0x', color: '#4B6584', textColor: '#FFFFFF' },
    { index: 7, multiplier: 3.0, label: '3.0x', color: '#FA8231', textColor: '#FFFFFF' },
    { index: 8, multiplier: 1.2, label: '1.2x', color: '#0FB9B1', textColor: '#FFFFFF' },
    { index: 9, multiplier: 1.5, label: '1.5x', color: '#3867D6', textColor: '#FFFFFF' },
    { index: 10, multiplier: 0.5, label: '0.5x', color: '#8854D0', textColor: '#FFFFFF' },
    { index: 11, multiplier: 5.0, label: '5.0x ⭐', color: '#FFD32A', textColor: '#000000' }
  ],
  high: [
    { index: 0, multiplier: 0.0, label: '0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 1, multiplier: 0.0, label: '0x', color: '#4B6584', textColor: '#FFFFFF' },
    { index: 2, multiplier: 2.0, label: '2.0x', color: '#20BF6B', textColor: '#FFFFFF' },
    { index: 3, multiplier: 0.0, label: '0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 4, multiplier: 5.0, label: '5.0x', color: '#3867D6', textColor: '#FFFFFF' },
    { index: 5, multiplier: 0.0, label: '0x', color: '#4B6584', textColor: '#FFFFFF' },
    { index: 6, multiplier: 10.0, label: '10x', color: '#FA8231', textColor: '#FFFFFF' },
    { index: 7, multiplier: 0.0, label: '0x', color: '#E51D35', textColor: '#FFFFFF' },
    { index: 8, multiplier: 25.0, label: '25x', color: '#8854D0', textColor: '#FFFFFF' },
    { index: 9, multiplier: 0.0, label: '0x', color: '#4B6584', textColor: '#FFFFFF' },
    { index: 10, multiplier: 50.0, label: '50x 🔥', color: '#FF9F1A', textColor: '#000000' },
    { index: 11, multiplier: 100.0, label: '100x 💎', color: '#FFD32A', textColor: '#000000' }
  ]
};

class WheelEngine {
  constructor() {
    this.history = [
      { id: 'w_seed_1', risk: 'medium', multiplier: 2.5, wonAmount: 250, time: new Date().toISOString() },
      { id: 'w_seed_2', risk: 'high', multiplier: 10.0, wonAmount: 1000, time: new Date().toISOString() },
      { id: 'w_seed_3', risk: 'medium', multiplier: 1.5, wonAmount: 150, time: new Date().toISOString() },
      { id: 'w_seed_4', risk: 'low', multiplier: 3.0, wonAmount: 300, time: new Date().toISOString() },
      { id: 'w_seed_5', risk: 'medium', multiplier: 0.0, wonAmount: 0, time: new Date().toISOString() }
    ];
  }

  // Deduct balance helper
  _deductUserBalance(userId, amount) {
    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    if (!wallet) return null;

    const totalBalance = wallet.deposit_balance + wallet.winning_balance + wallet.bonus_balance;
    if (amount > totalBalance) return null;

    let rem = amount;
    let newBonus = wallet.bonus_balance;
    let newDeposit = wallet.deposit_balance;
    let newWinning = wallet.winning_balance;

    if (newBonus >= rem) {
      newBonus -= rem;
      rem = 0;
    } else {
      rem -= newBonus;
      newBonus = 0;
      if (newDeposit >= rem) {
        newDeposit -= rem;
        rem = 0;
      } else {
        rem -= newDeposit;
        newDeposit = 0;
        newWinning = Math.max(0, newWinning - rem);
      }
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE wallets
      SET deposit_balance = ?, winning_balance = ?, bonus_balance = ?, updated_at = ?
      WHERE user_id = ?
    `).run(newDeposit, newWinning, newBonus, now, userId);

    return db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
  }

  // Credit winnings helper
  _creditUserWinnings(userId, amount) {
    const now = new Date().toISOString();
    db.prepare(`
      UPDATE wallets
      SET winning_balance = winning_balance + ?, updated_at = ?
      WHERE user_id = ?
    `).run(amount, now, userId);
    return db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
  }

  getSegments(risk = 'medium') {
    return WHEEL_PRESETS[risk] || WHEEL_PRESETS.medium;
  }

  spin({ userId, amount, risk = 'medium' }) {
    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount <= 0) {
      return { success: false, error: 'Invalid bet amount' };
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return { success: false, error: 'User not found' };
    }

    const updatedWallet = this._deductUserBalance(userId, numAmount);
    if (!updatedWallet) {
      const w = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      const bal = w ? w.deposit_balance + w.winning_balance + w.bonus_balance : 0;
      return { success: false, error: `Insufficient wallet balance (Available: ₹${bal})` };
    }

    const roundId = `w_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const serverSeed = crypto.randomBytes(32).toString('hex');
    const hash = crypto.createHash('sha256').update(serverSeed).digest('hex');

    const segments = this.getSegments(risk);
    const segmentCount = segments.length;

    // Provably fair landing segment
    const rand = Math.random();
    const landingIndex = Math.floor(rand * segmentCount);
    const landingSegment = segments[landingIndex];
    const multiplier = landingSegment.multiplier;
    const wonAmount = Math.round(numAmount * multiplier);
    const now = new Date().toISOString();

    let finalWallet = updatedWallet;

    // Record entry fee transaction
    try {
      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_${roundId}`,
        userId,
        'entry_fee',
        numAmount,
        'completed',
        `Lucky Wheel Spin (${risk.toUpperCase()})`,
        `Bet ₹${numAmount} on ${risk} risk wheel`,
        now,
        roundId
      );
    } catch (e) {
      console.error('[WheelEngine] DB txn error:', e);
    }

    // If won > 0, credit winning balance and record win
    if (wonAmount > 0) {
      finalWallet = this._creditUserWinnings(userId, wonAmount);

      try {
        db.prepare(`
          INSERT INTO transactions (
            id, user_id, type, amount, status, title, description, timestamp, reference_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          `TXN_WHEEL_WIN_${roundId}`,
          userId,
          'prize_won',
          wonAmount,
          'completed',
          `Lucky Wheel Win @ ${multiplier}x`,
          `Won ₹${wonAmount} with ₹${numAmount} bet (${landingSegment.label})`,
          now,
          roundId
        );

        if (multiplier >= 2.0) {
          db.prepare(`
            INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
            VALUES (?, ?, ?, ?, ?, ?, ?)
          `).run(
            `notif_wheel_${Date.now()}`,
            userId,
            'Lucky Wheel Mega Win! 🎡',
            `You won ₹${wonAmount} at ${multiplier}x multiplier!`,
            'win',
            now,
            0
          );
        }
      } catch (e) {
        console.error('[WheelEngine] DB win record error:', e);
      }
    }

    // Add to history
    this.history.unshift({
      id: roundId,
      risk,
      multiplier,
      wonAmount,
      label: landingSegment.label,
      time: now
    });
    if (this.history.length > 25) this.history.pop();

    return {
      success: true,
      message: wonAmount > 0 ? `Landed on ${landingSegment.label}! Won ₹${wonAmount}` : `Landed on ${landingSegment.label}`,
      roundId,
      risk,
      landingIndex,
      segment: landingSegment,
      multiplier,
      wonAmount,
      isWin: wonAmount > 0,
      serverSeed,
      hash,
      wallet: formatWallet(finalWallet)
    };
  }

  getHistory() {
    return this.history.slice(0, 20);
  }
}

const wheelEngine = new WheelEngine();

module.exports = {
  wheelEngine,
  WHEEL_PRESETS
};
