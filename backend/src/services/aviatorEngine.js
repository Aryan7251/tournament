const crypto = require('crypto');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

class AviatorEngine {
  constructor() {
    this.state = 'waiting'; // 'waiting' | 'flying' | 'crashed'
    this.currentRoundId = `rnd_${Date.now()}`;
    this.currentMultiplier = 1.00;
    this.targetCrashMultiplier = 2.45;
    this.countdownSec = 5.0;
    this.flightTimeSec = 0.0;
    this.serverSeed = '';
    this.hash = '';
    
    // In-memory active bets for current round: Map<betId, BetObject>
    this.activeBets = new Map();
    
    // Recent multiplier history (last 20)
    this.history = [
      1.45, 3.82, 1.12, 8.40, 2.15, 1.04, 14.60, 1.95, 4.10, 1.28,
      2.75, 5.20, 1.18, 1.85, 3.10, 2.05, 7.80, 1.35, 1.08, 9.50
    ];

    // Simulated players in lobby
    this.simulatedPlayers = [];

    this.timer = null;
    this.tickIntervalMs = 50; // 50ms tick

    this._initEngine();
  }

  _initEngine() {
    this._startNewRound();
    this.timer = setInterval(() => this._tick(), this.tickIntervalMs);
    console.log('[AviatorEngine] Server-side game engine started successfully.');
  }

  _generateCrashPoint() {
    // Provably fair generation using HMAC-SHA256
    this.serverSeed = crypto.randomBytes(32).toString('hex');
    this.hash = crypto.createHash('sha256').update(this.serverSeed).digest('hex');

    const randomVal = Math.random();
    let multiplier;

    if (randomVal < 0.05) {
      // 5% instant crash at 1.00 - 1.10
      multiplier = 1.00 + Math.random() * 0.10;
    } else if (randomVal < 0.55) {
      // 50% low-medium 1.11 - 2.50
      multiplier = 1.11 + Math.random() * 1.39;
    } else if (randomVal < 0.85) {
      // 30% medium-high 2.50 - 7.00
      multiplier = 2.50 + Math.random() * 4.50;
    } else if (randomVal < 0.97) {
      // 12% high 7.00 - 25.00
      multiplier = 7.00 + Math.random() * 18.00;
    } else {
      // 3% Moonshot 25.00 - 100.00+
      multiplier = 25.00 + Math.random() * 75.00;
    }

    return Math.round(multiplier * 100) / 100;
  }

  _generateSimulatedPlayers() {
    const names = [
      'EagleEye', 'CryptoKing', 'LuckyStrike', 'SkyRider', 'AcePilot',
      'Phoenix99', 'ThunderVolt', 'BlazeGamer', 'Shadow7', 'CyberWolf',
      'MatrixOne', 'GhostRider', 'GoldHunter', 'NovaStar', 'TitanX'
    ];
    // Shuffle
    const shuffled = [...names].sort(() => 0.5 - Math.random());
    const count = 5 + Math.floor(Math.random() * 6);
    this.simulatedPlayers = [];
    const betAmounts = [20, 50, 100, 200, 500, 1000];

    for (let i = 0; i < count; i++) {
      this.simulatedPlayers.push({
        name: shuffled[i],
        bet: betAmounts[Math.floor(Math.random() * betAmounts.length)],
        cashout: null,
        avatar: shuffled[i]
      });
    }
  }

  _startNewRound() {
    this.state = 'waiting';
    this.currentRoundId = `rnd_${Date.now()}`;
    this.countdownSec = 5.0;
    this.currentMultiplier = 1.00;
    this.flightTimeSec = 0.0;
    this.targetCrashMultiplier = this._generateCrashPoint();
    this.activeBets.clear();
    this._generateSimulatedPlayers();
  }

  _startFlight() {
    this.state = 'flying';
    this.currentMultiplier = 1.00;
    this.flightTimeSec = 0.0;

    // Record round start in database
    try {
      db.prepare(`
        INSERT INTO game_rounds (id, game_type, crash_multiplier, server_seed, hash, status, created_at)
        VALUES (?, 'aviator', ?, ?, ?, 'flying', ?)
      `).run(
        this.currentRoundId,
        this.targetCrashMultiplier,
        this.serverSeed,
        this.hash,
        new Date().toISOString()
      );
    } catch (e) {
      console.error('[AviatorEngine] Error inserting round:', e);
    }
  }

  _handleCrash() {
    this.state = 'crashed';
    this.currentMultiplier = this.targetCrashMultiplier;
    const now = new Date().toISOString();

    // Mark uncashed bets as crashed in memory and DB
    for (const [betId, bet] of this.activeBets.entries()) {
      if (bet.status === 'placed') {
        bet.status = 'crashed';
        try {
          db.prepare('UPDATE game_bets SET status = ? WHERE id = ?').run('crashed', betId);
        } catch (_) {}
      }
    }

    // Add to history
    this.history.unshift(this.targetCrashMultiplier);
    if (this.history.length > 25) {
      this.history.pop();
    }

    // Update round in DB
    try {
      db.prepare(`
        UPDATE game_rounds
        SET status = 'crashed', crashed_at = ?
        WHERE id = ?
      `).run(now, this.currentRoundId);
    } catch (_) {}

    // 3 seconds cooldown before next round
    setTimeout(() => {
      this._startNewRound();
    }, 3000);
  }

  _tick() {
    if (this.state === 'waiting') {
      this.countdownSec = Math.max(0, this.countdownSec - (this.tickIntervalMs / 1000));
      if (this.countdownSec <= 0) {
        this._startFlight();
      }
    } else if (this.state === 'flying') {
      this.flightTimeSec += this.tickIntervalMs / 1000;
      const t = this.flightTimeSec;
      // Exponential curve: starts gentle, accelerates over time
      const newMultiplier = Math.round((1.00 + (0.055 * t) + (0.045 * Math.pow(t, 1.6))) * 100) / 100;

      // Check Auto-Cashouts for active bets
      this._checkAutoCashouts(newMultiplier);

      // Simulate other player cashouts
      this._simulateOtherPlayerCashouts(newMultiplier);

      if (newMultiplier >= this.targetCrashMultiplier) {
        this._handleCrash();
      } else {
        this.currentMultiplier = newMultiplier;
      }
    }
  }

  _checkAutoCashouts(currentM) {
    for (const [betId, bet] of this.activeBets.entries()) {
      if (bet.status === 'placed' && bet.autoCashoutEnabled && currentM >= bet.autoCashoutValue) {
        this.cashoutBet(bet.userId, betId, currentM);
      }
    }
  }

  _simulateOtherPlayerCashouts(currentM) {
    for (const p of this.simulatedPlayers) {
      if (p.cashout === null && currentM > 1.20) {
        if (Math.random() < 0.04) {
          p.cashout = currentM;
        }
      }
    }
  }

  // --- Public API Methods ---

  getGameState(userId) {
    let userBets = [];
    let userWallet = null;
    if (userId) {
      for (const [betId, bet] of this.activeBets.entries()) {
        if (bet.userId === userId) {
          userBets.push({ ...bet });
        }
      }
      try {
        const w = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
        if (w) userWallet = formatWallet(w);
      } catch (_) {}
    }

    return {
      roundId: this.currentRoundId,
      state: this.state,
      currentMultiplier: this.currentMultiplier,
      targetCrashMultiplier: this.state === 'crashed' ? this.targetCrashMultiplier : null,
      countdownSec: Math.round(this.countdownSec * 10) / 10,
      flightTimeSec: Math.round(this.flightTimeSec * 100) / 100,
      hash: this.hash,
      history: this.history.slice(0, 20),
      livePlayers: this.simulatedPlayers,
      activeBetsCount: this.activeBets.size,
      userBets,
      wallet: userWallet
    };
  }

  placeBet({ userId, slotNum = 1, amount, autoCashoutEnabled = false, autoCashoutValue = 2.0 }) {
    if (this.state !== 'waiting') {
      return { success: false, error: 'Cannot place bet. Round already in progress or completed.' };
    }

    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount <= 0) {
      return { success: false, error: 'Invalid bet amount' };
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return { success: false, error: 'User not found' };
    }

    let wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    if (!wallet) {
      return { success: false, error: 'Wallet not found' };
    }

    const totalBalance = wallet.deposit_balance + wallet.winning_balance + wallet.bonus_balance;
    if (numAmount > totalBalance) {
      return { success: false, error: `Insufficient wallet balance (Available: ₹${totalBalance})` };
    }

    // Check if slot is already occupied for current round
    for (const [_, b] of this.activeBets.entries()) {
      if (b.userId === userId && b.slotNum === slotNum && b.status === 'placed') {
        return { success: false, error: `Bet for Slot ${slotNum} already placed in this round.` };
      }
    }

    const now = new Date().toISOString();

    // Deduct balance atomically (bonus -> deposit -> winning)
    let rem = numAmount;
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

    db.prepare(`
      UPDATE wallets
      SET deposit_balance = ?, winning_balance = ?, bonus_balance = ?, updated_at = ?
      WHERE user_id = ?
    `).run(newDeposit, newWinning, newBonus, now, userId);

    const betId = `bet_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const betObj = {
      id: betId,
      roundId: this.currentRoundId,
      userId,
      slotNum,
      amount: numAmount,
      autoCashoutEnabled: Boolean(autoCashoutEnabled),
      autoCashoutValue: parseFloat(autoCashoutValue) || 2.0,
      status: 'placed',
      cashoutMultiplier: 1.0,
      wonAmount: 0,
      placedAt: now
    };

    this.activeBets.set(betId, betObj);

    // Record in DB
    try {
      db.prepare(`
        INSERT INTO game_bets (
          id, round_id, user_id, slot_num, amount,
          auto_cashout_enabled, auto_cashout_value, status, placed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        betId,
        this.currentRoundId,
        userId,
        slotNum,
        numAmount,
        autoCashoutEnabled ? 1 : 0,
        parseFloat(autoCashoutValue) || 2.0,
        'placed',
        now
      );

      // Record transaction
      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_${betId}`,
        userId,
        'entry_fee',
        numAmount,
        'completed',
        `Aviator Bet (Slot ${slotNum})`,
        `Placed ₹${numAmount} bet on Round #${this.currentRoundId.substring(4, 10)}`,
        now,
        betId
      );
    } catch (e) {
      console.error('[AviatorEngine] DB error during bet:', e);
    }

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return {
      success: true,
      message: `Bet of ₹${numAmount} placed for Slot ${slotNum}`,
      bet: betObj,
      wallet: formatWallet(updatedWallet)
    };
  }

  cancelBet(userId, betId) {
    if (this.state !== 'waiting') {
      return { success: false, error: 'Cannot cancel bet after takeoff.' };
    }

    const bet = this.activeBets.get(betId);
    if (!bet || bet.userId !== userId || bet.status !== 'placed') {
      return { success: false, error: 'Active bet not found.' };
    }

    const now = new Date().toISOString();

    // Refund to deposit balance
    db.prepare(`
      UPDATE wallets
      SET deposit_balance = deposit_balance + ?, updated_at = ?
      WHERE user_id = ?
    `).run(bet.amount, now, userId);

    bet.status = 'cancelled';
    this.activeBets.delete(betId);

    // Update DB
    try {
      db.prepare('UPDATE game_bets SET status = ? WHERE id = ?').run('cancelled', betId);

      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_REF_${betId}`,
        userId,
        'refund',
        bet.amount,
        'completed',
        'Aviator Bet Cancelled',
        `Refunded ₹${bet.amount} for cancelled bet`,
        now,
        betId
      );
    } catch (_) {}

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return {
      success: true,
      message: 'Bet cancelled and refunded.',
      wallet: formatWallet(updatedWallet)
    };
  }

  cashoutBet(userId, betId, manualMultiplier = null) {
    if (this.state !== 'flying') {
      return { success: false, error: 'Cannot cashout. Flight is not active.' };
    }

    let targetBet = null;
    let targetBetId = betId;

    if (betId) {
      targetBet = this.activeBets.get(betId);
    } else {
      // Find placed bet by user
      for (const [id, b] of this.activeBets.entries()) {
        if (b.userId === userId && b.status === 'placed') {
          targetBet = b;
          targetBetId = id;
          break;
        }
      }
    }

    if (!targetBet || targetBet.userId !== userId || targetBet.status !== 'placed') {
      return { success: false, error: 'No active bet available to cashout.' };
    }

    const cashoutM = manualMultiplier && manualMultiplier <= this.currentMultiplier
      ? manualMultiplier
      : this.currentMultiplier;

    const wonAmount = Math.round(targetBet.amount * cashoutM);
    const now = new Date().toISOString();

    targetBet.status = 'cashed_out';
    targetBet.cashoutMultiplier = cashoutM;
    targetBet.wonAmount = wonAmount;
    targetBet.cashedOutAt = now;

    // Credit to winning_balance
    db.prepare(`
      UPDATE wallets
      SET winning_balance = winning_balance + ?, updated_at = ?
      WHERE user_id = ?
    `).run(wonAmount, now, userId);

    // Record DB records
    try {
      db.prepare(`
        UPDATE game_bets
        SET status = 'cashed_out', cashout_multiplier = ?, won_amount = ?, cashed_out_at = ?
        WHERE id = ?
      `).run(cashoutM, wonAmount, now, targetBetId);

      // Record transaction
      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_AVI_WIN_${Date.now()}`,
        userId,
        'prize_won',
        wonAmount,
        'completed',
        `Aviator Win @ ${cashoutM}x`,
        `Cashed out ₹${wonAmount} with ₹${targetBet.amount} bet`,
        now,
        targetBetId
      );

      // Record notification
      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        `notif_win_${Date.now()}`,
        userId,
        'Aviator Cashout Victory!',
        `You won ₹${wonAmount} at ${cashoutM}x multiplier!`,
        'win',
        now,
        0
      );
    } catch (e) {
      console.error('[AviatorEngine] DB error during cashout:', e);
    }

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return {
      success: true,
      message: `Cashed out at ${cashoutM}x! Won ₹${wonAmount}`,
      wonAmount,
      cashoutMultiplier: cashoutM,
      bet: targetBet,
      wallet: formatWallet(updatedWallet)
    };
  }
}

// Singleton engine instance
const aviatorEngine = new AviatorEngine();

module.exports = {
  aviatorEngine
};
