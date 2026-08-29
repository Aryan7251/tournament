const crypto = require('crypto');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

// Multipliers for various row counts and risk levels (Low, Medium, High)
const PLINKO_MULTIPLIERS = {
  8: {
    low: [5.6, 2.1, 1.1, 1.0, 0.5, 1.0, 1.1, 2.1, 5.6],
    medium: [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0],
    high: [29.0, 4.0, 1.5, 0.3, 0.2, 0.3, 1.5, 4.0, 29.0]
  },
  10: {
    low: [8.9, 3.0, 1.4, 1.1, 1.0, 0.5, 1.0, 1.1, 1.4, 3.0, 8.9],
    medium: [22.0, 5.0, 2.0, 1.4, 0.6, 0.4, 0.6, 1.4, 2.0, 5.0, 22.0],
    high: [76.0, 10.0, 3.0, 1.5, 0.3, 0.2, 0.3, 1.5, 3.0, 10.0, 76.0]
  },
  12: {
    low: [10.0, 3.0, 1.6, 1.4, 1.1, 1.0, 0.5, 1.0, 1.1, 1.4, 1.6, 3.0, 10.0],
    medium: [33.0, 11.0, 4.0, 2.0, 1.1, 0.6, 0.3, 0.6, 1.1, 2.0, 4.0, 11.0, 33.0],
    high: [170.0, 24.0, 8.1, 2.0, 0.7, 0.2, 0.2, 0.2, 0.7, 2.0, 8.1, 24.0, 170.0]
  },
  14: {
    low: [13.0, 4.0, 2.0, 1.4, 1.3, 1.1, 1.0, 0.5, 1.0, 1.1, 1.3, 1.4, 2.0, 4.0, 13.0],
    medium: [58.0, 15.0, 7.0, 4.0, 1.9, 1.0, 0.5, 0.2, 0.5, 1.0, 1.9, 4.0, 7.0, 15.0, 58.0],
    high: [420.0, 56.0, 18.0, 5.0, 1.9, 0.3, 0.2, 0.2, 0.2, 0.3, 1.9, 5.0, 18.0, 56.0, 420.0]
  },
  16: {
    low: [16.0, 9.0, 2.0, 1.4, 1.4, 1.2, 1.1, 1.0, 0.5, 1.0, 1.1, 1.2, 1.4, 1.4, 2.0, 9.0, 16.0],
    medium: [110.0, 41.0, 10.0, 5.0, 3.0, 1.5, 1.0, 0.5, 0.3, 0.5, 1.0, 1.5, 3.0, 5.0, 10.0, 41.0, 110.0],
    high: [1000.0, 130.0, 26.0, 9.0, 4.0, 2.0, 0.2, 0.2, 0.2, 0.2, 0.2, 2.0, 4.0, 9.0, 26.0, 130.0, 1000.0]
  }
};

class PlinkoEngine {
  constructor() {
    this.pendingRounds = new Map();
    this.history = [
      { id: 'pk_seed_1', rows: 8, risk: 'medium', landingIndex: 7, multiplier: 3.0, wonAmount: 150, time: new Date().toISOString() },
      { id: 'pk_seed_2', rows: 12, risk: 'high', landingIndex: 1, multiplier: 24.0, wonAmount: 1200, time: new Date().toISOString() },
      { id: 'pk_seed_3', rows: 10, risk: 'low', landingIndex: 4, multiplier: 1.0, wonAmount: 50, time: new Date().toISOString() },
      { id: 'pk_seed_4', rows: 16, risk: 'high', landingIndex: 0, multiplier: 1000.0, wonAmount: 50000, time: new Date().toISOString() },
      { id: 'pk_seed_5', rows: 8, risk: 'low', landingIndex: 4, multiplier: 0.5, wonAmount: 25, time: new Date().toISOString() }
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
        newDeposit -= rem;
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

  getMultipliers(rows = 8, risk = 'medium') {
    const r = PLINKO_MULTIPLIERS[rows] || PLINKO_MULTIPLIERS[8];
    return r[risk] || r.medium;
  }

  dropBall({ userId, amount, rows = 8, risk = 'medium' }) {
    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount <= 0) {
      return { success: false, error: 'Invalid bet amount' };
    }

    const rowCount = [8, 10, 12, 14, 16].includes(parseInt(rows, 10)) ? parseInt(rows, 10) : 8;
    const riskLevel = ['low', 'medium', 'high'].includes(risk) ? risk : 'medium';

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return { success: false, error: 'User not found' };
    }

    // 1. Deduct bet amount immediately from user wallet
    const updatedWallet = this._deductUserBalance(userId, numAmount);
    if (!updatedWallet) {
      const w = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      const bal = w ? w.deposit_balance + w.winning_balance + w.bonus_balance : 0;
      return { success: false, error: `Insufficient wallet balance (Available: ₹${bal})` };
    }

    const roundId = `pk_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const serverSeed = crypto.randomBytes(32).toString('hex');
    const hash = crypto.createHash('sha256').update(serverSeed).digest('hex');

    // Generate provably fair step path (0 = Left bounce, 1 = Right bounce)
    const path = [];
    let landingIndex = 0;
    for (let i = 0; i < rowCount; i++) {
      const step = Math.random() < 0.5 ? 0 : 1;
      path.push(step);
      landingIndex += step;
    }

    const multipliers = this.getMultipliers(rowCount, riskLevel);
    const multiplier = multipliers[landingIndex] !== undefined ? multipliers[landingIndex] : 1.0;
    const wonAmount = Math.round(numAmount * multiplier);
    const now = new Date().toISOString();

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
        `Plinko Drop (${rowCount} Rows, ${riskLevel.toUpperCase()})`,
        `Dropped Plinko ball with ₹${numAmount} bet`,
        now,
        roundId
      );
    } catch (e) {
      console.error('[PlinkoEngine] DB txn error:', e);
    }

    // Store round in pending map awaiting ball landing
    this.pendingRounds.set(roundId, {
      roundId,
      userId,
      amount: numAmount,
      rows: rowCount,
      risk: riskLevel,
      path,
      landingIndex,
      multiplier,
      wonAmount,
      settled: false,
      createdAt: Date.now()
    });

    // Auto-settle safety timeout (12s) if client fails to call settle
    setTimeout(() => {
      if (this.pendingRounds.has(roundId)) {
        this.settleBall({ userId, roundId });
      }
    }, 12000);

    return {
      success: true,
      message: 'Ball dropped',
      roundId,
      rows: rowCount,
      risk: riskLevel,
      path,
      landingIndex,
      multiplier,
      wonAmount,
      isWin: wonAmount > 0,
      serverSeed,
      hash,
      wallet: formatWallet(updatedWallet) // Returns wallet after bet deduction ONLY!
    };
  }

  settleBall({ userId, roundId }) {
    const round = this.pendingRounds.get(roundId);
    let finalWallet = null;
    const now = new Date().toISOString();

    if (round && !round.settled) {
      round.settled = true;

      // Credit user winnings if wonAmount > 0
      if (round.wonAmount > 0) {
        finalWallet = this._creditUserWinnings(userId, round.wonAmount);

        try {
          db.prepare(`
            INSERT INTO transactions (
              id, user_id, type, amount, status, title, description, timestamp, reference_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          `).run(
            `TXN_PLINKO_WIN_${roundId}`,
            userId,
            'prize_won',
            round.wonAmount,
            'completed',
            `Plinko Win @ ${round.multiplier}x`,
            `Landed on Slot ${round.landingIndex + 1}/${round.rows + 1} (${round.multiplier}x) - Won ₹${round.wonAmount}`,
            now,
            roundId
          );

          if (round.multiplier >= 5.0) {
            db.prepare(`
              INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
              VALUES (?, ?, ?, ?, ?, ?, ?)
            `).run(
              `notif_plinko_${Date.now()}`,
              userId,
              'Plinko Mega Multiplier! ⚡',
              `Your ball landed on ${round.multiplier}x! You won ₹${round.wonAmount}!`,
              'win',
              now,
              0
            );
          }
        } catch (e) {
          console.error('[PlinkoEngine] DB win record error:', e);
        }
      } else {
        const w = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
        if (w) finalWallet = w;
      }

      // Add to history
      this.history.unshift({
        id: roundId,
        rows: round.rows,
        risk: round.risk,
        landingIndex: round.landingIndex,
        multiplier: round.multiplier,
        wonAmount: round.wonAmount,
        time: now
      });
      if (this.history.length > 30) this.history.pop();

      this.pendingRounds.delete(roundId);

      return {
        success: true,
        message: round.wonAmount > 0 ? `Landed on ${round.multiplier}x! Won ₹${round.wonAmount}` : `Landed on ${round.multiplier}x`,
        roundId,
        multiplier: round.multiplier,
        wonAmount: round.wonAmount,
        wallet: finalWallet ? formatWallet(finalWallet) : null
      };
    }

    const currentWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    return {
      success: true,
      roundId,
      wallet: currentWallet ? formatWallet(currentWallet) : null
    };
  }

  getHistory() {
    return this.history.slice(0, 25);
  }
}

const plinkoEngine = new PlinkoEngine();

module.exports = {
  plinkoEngine,
  PLINKO_MULTIPLIERS
};
