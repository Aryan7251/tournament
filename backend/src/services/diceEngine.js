const crypto = require('crypto');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

class DiceEngine {
  constructor() {
    this.history = [
      { id: 'd_seed_1', mode: 'slider', rollResult: 34.20, target: 50.0, condition: 'under', isWin: true, multiplier: 1.98, wonAmount: 198, time: new Date().toISOString() },
      { id: 'd_seed_2', mode: 'dual', dice1: 4, dice2: 3, sum: 7, choice: 'seven', isWin: true, multiplier: 5.80, wonAmount: 580, time: new Date().toISOString() },
      { id: 'd_seed_3', mode: 'slider', rollResult: 78.50, target: 45.0, condition: 'under', isWin: false, multiplier: 2.20, wonAmount: 0, time: new Date().toISOString() },
      { id: 'd_seed_4', mode: 'dual', dice1: 5, dice2: 6, sum: 11, choice: 'high', isWin: true, multiplier: 2.30, wonAmount: 230, time: new Date().toISOString() },
      { id: 'd_seed_5', mode: 'slider', rollResult: 88.12, target: 70.0, condition: 'over', isWin: true, multiplier: 3.30, wonAmount: 330, time: new Date().toISOString() }
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

  roll({
    userId,
    amount,
    mode = 'slider', // 'slider' | 'dual'
    target = 50.0,
    condition = 'under', // 'under' | 'over'
    choice = 'low' // 'low' | 'seven' | 'high' | 'even' | 'odd'
  }) {
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

    const roundId = `d_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const serverSeed = crypto.randomBytes(32).toString('hex');
    const hash = crypto.createHash('sha256').update(serverSeed).digest('hex');
    const now = new Date().toISOString();

    let isWin = false;
    let multiplier = 1.0;
    let rollResult = 0.0;
    let dice1 = 1;
    let dice2 = 1;
    let sum = 2;
    let winChance = 49.5;

    if (mode === 'slider') {
      const numTarget = Math.max(1.0, Math.min(98.0, parseFloat(target) || 50.0));
      rollResult = Math.round(Math.random() * 99.99 * 100) / 100;

      if (condition === 'under') {
        winChance = numTarget;
        isWin = rollResult < numTarget;
      } else {
        winChance = 100.0 - numTarget;
        isWin = rollResult > numTarget;
      }

      // 99% RTP / 1% House Edge
      multiplier = Math.max(1.01, Math.round((99.0 / winChance) * 100) / 100);
    } else {
      // Dual Cyber Dice Mode
      dice1 = 1 + Math.floor(Math.random() * 6);
      dice2 = 1 + Math.floor(Math.random() * 6);
      sum = dice1 + dice2;
      rollResult = sum;

      if (choice === 'low') {
        isWin = sum >= 2 && sum <= 6;
        multiplier = 2.30;
      } else if (choice === 'seven') {
        isWin = sum === 7;
        multiplier = 5.80;
      } else if (choice === 'high') {
        isWin = sum >= 8 && sum <= 12;
        multiplier = 2.30;
      } else if (choice === 'even') {
        isWin = sum % 2 === 0;
        multiplier = 1.95;
      } else if (choice === 'odd') {
        isWin = sum % 2 !== 0;
        multiplier = 1.95;
      }
    }

    const wonAmount = isWin ? Math.round(numAmount * multiplier) : 0;
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
        `Cyber Dice (${mode === 'slider' ? `${condition} ${target}` : choice.toUpperCase()})`,
        `Placed ₹${numAmount} bet on Cyber Dice`,
        now,
        roundId
      );
    } catch (e) {
      console.error('[DiceEngine] DB txn error:', e);
    }

    // If won, credit winnings
    if (isWin && wonAmount > 0) {
      finalWallet = this._creditUserWinnings(userId, wonAmount);

      try {
        db.prepare(`
          INSERT INTO transactions (
            id, user_id, type, amount, status, title, description, timestamp, reference_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          `TXN_DICE_WIN_${roundId}`,
          userId,
          'prize_won',
          wonAmount,
          'completed',
          `Cyber Dice Win @ ${multiplier}x`,
          `Won ₹${wonAmount} with ₹${numAmount} bet (Roll: ${mode === 'slider' ? rollResult : `${dice1}+${dice2}=${sum}`})`,
          now,
          roundId
        );

        if (multiplier >= 2.0) {
          db.prepare(`
            INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
            VALUES (?, ?, ?, ?, ?, ?, ?)
          `).run(
            `notif_dice_${Date.now()}`,
            userId,
            'Cyber Dice Victory! 🎲',
            `You won ₹${wonAmount} at ${multiplier}x multiplier!`,
            'win',
            now,
            0
          );
        }
      } catch (e) {
        console.error('[DiceEngine] DB win record error:', e);
      }
    }

    // Add to history
    this.history.unshift({
      id: roundId,
      mode,
      rollResult,
      dice1,
      dice2,
      sum,
      target,
      condition,
      choice,
      isWin,
      multiplier,
      wonAmount,
      time: now
    });
    if (this.history.length > 25) this.history.pop();

    return {
      success: true,
      message: isWin ? `Rolled ${mode === 'slider' ? rollResult : sum}! Won ₹${wonAmount}` : `Rolled ${mode === 'slider' ? rollResult : sum}`,
      roundId,
      mode,
      rollResult,
      dice1,
      dice2,
      sum,
      isWin,
      multiplier,
      wonAmount,
      target,
      condition,
      choice,
      winChance,
      serverSeed,
      hash,
      wallet: formatWallet(finalWallet)
    };
  }

  getHistory() {
    return this.history.slice(0, 20);
  }
}

const diceEngine = new DiceEngine();

module.exports = {
  diceEngine
};
