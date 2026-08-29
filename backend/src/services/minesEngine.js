const crypto = require('crypto');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

// Helper to calculate binomial coefficient C(n, k)
function combinations(n, k) {
  if (k < 0 || k > n) return 0;
  if (k === 0 || k === n) return 1;
  let c = 1;
  for (let i = 1; i <= k; i++) {
    c = (c * (n - (k - i))) / i;
  }
  return c;
}

// Calculate Mines Multiplier for a given mine count and gems revealed
function calculateMinesMultiplier(mineCount, gemsRevealed) {
  if (gemsRevealed <= 0) return 1.0;
  const totalTiles = 25;
  const totalGems = totalTiles - mineCount;
  if (gemsRevealed > totalGems) return 0;

  // House edge 3% (97% RTP)
  const houseEdge = 0.97;
  const prob = combinations(totalGems, gemsRevealed) / combinations(totalTiles, gemsRevealed);
  const mult = (1 / prob) * houseEdge;
  return Math.max(1.01, Math.round(mult * 100) / 100);
}

class MinesEngine {
  constructor() {
    // Map<roundId, MinesSession>
    this.sessions = new Map();
    // In-memory recent history
    this.history = [
      { id: 'm_seed_1', mineCount: 3, gemsRevealed: 5, multiplier: 2.06, wonAmount: 206, status: 'cashed_out', time: new Date().toISOString() },
      { id: 'm_seed_2', mineCount: 5, gemsRevealed: 4, multiplier: 2.82, wonAmount: 564, status: 'cashed_out', time: new Date().toISOString() },
      { id: 'm_seed_3', mineCount: 3, gemsRevealed: 2, multiplier: 1.29, wonAmount: 129, status: 'cashed_out', time: new Date().toISOString() },
      { id: 'm_seed_4', mineCount: 10, gemsRevealed: 2, multiplier: 2.69, wonAmount: 0, status: 'exploded', time: new Date().toISOString() },
      { id: 'm_seed_5', mineCount: 1, gemsRevealed: 8, multiplier: 1.45, wonAmount: 725, status: 'cashed_out', time: new Date().toISOString() }
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

  // Generate random mine positions (0 to 24)
  _generateMinePositions(mineCount) {
    const all = Array.from({ length: 25 }, (_, i) => i);
    // Fisher-Yates shuffle
    for (let i = all.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [all[i], all[j]] = [all[j], all[i]];
    }
    return new Set(all.slice(0, mineCount));
  }

  // Start a new Mines Game
  startGame({ userId, amount, mineCount = 3 }) {
    const numAmount = parseInt(amount, 10);
    const numMines = parseInt(mineCount, 10);

    if (isNaN(numAmount) || numAmount <= 0) {
      return { success: false, error: 'Invalid bet amount' };
    }
    if (isNaN(numMines) || numMines < 1 || numMines > 24) {
      return { success: false, error: 'Mine count must be between 1 and 24' };
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return { success: false, error: 'User not found' };
    }

    // Check if user already has an active session
    for (const [sId, s] of this.sessions.entries()) {
      if (s.userId === userId && s.status === 'active') {
        return {
          success: true,
          message: 'Restored active Mines game',
          restored: true,
          round: this._formatSession(s)
        };
      }
    }

    const updatedWallet = this._deductUserBalance(userId, numAmount);
    if (!updatedWallet) {
      const w = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      const bal = w ? w.deposit_balance + w.winning_balance + w.bonus_balance : 0;
      return { success: false, error: `Insufficient wallet balance (Available: ₹${bal})` };
    }

    const roundId = `m_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const serverSeed = crypto.randomBytes(32).toString('hex');
    const hash = crypto.createHash('sha256').update(serverSeed).digest('hex');
    const minePositions = this._generateMinePositions(numMines);
    const now = new Date().toISOString();

    const session = {
      id: roundId,
      userId,
      amount: numAmount,
      mineCount: numMines,
      minePositions,
      revealedIndices: new Set(),
      currentMultiplier: 1.0,
      wonAmount: 0,
      status: 'active', // 'active' | 'exploded' | 'cashed_out'
      serverSeed,
      hash,
      startedAt: now
    };

    this.sessions.set(roundId, session);

    // Record transaction
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
        `Mines Gold (${numMines} Mines)`,
        `Placed ₹${numAmount} bet on Mine Gold with ${numMines} mines`,
        now,
        roundId
      );
    } catch (e) {
      console.error('[MinesEngine] DB transaction error:', e);
    }

    return {
      success: true,
      message: 'Mines game started!',
      round: this._formatSession(session),
      wallet: formatWallet(updatedWallet)
    };
  }

  // Reveal a tile (0 to 24)
  revealTile({ userId, roundId, tileIndex }) {
    const idx = parseInt(tileIndex, 10);
    if (isNaN(idx) || idx < 0 || idx > 24) {
      return { success: false, error: 'Invalid tile index (0-24)' };
    }

    const session = this.sessions.get(roundId);
    if (!session || session.userId !== userId) {
      return { success: false, error: 'Game round not found' };
    }

    if (session.status !== 'active') {
      return { success: false, error: 'Game round already completed' };
    }

    if (session.revealedIndices.has(idx)) {
      return { success: false, error: 'Tile already revealed' };
    }

    const now = new Date().toISOString();

    // 1. Check if Tile is a Mine -> EXPLODED!
    if (session.minePositions.has(idx)) {
      session.status = 'exploded';
      session.revealedIndices.add(idx);
      session.wonAmount = 0;

      const allMines = Array.from(session.minePositions);

      // Add to history
      this.history.unshift({
        id: session.id,
        mineCount: session.mineCount,
        gemsRevealed: session.revealedIndices.size - 1,
        multiplier: 0,
        wonAmount: 0,
        status: 'exploded',
        time: now
      });
      if (this.history.length > 25) this.history.pop();

      return {
        success: true,
        status: 'exploded',
        isMine: true,
        tileIndex: idx,
        allMines,
        multiplier: 0,
        wonAmount: 0,
        round: this._formatSession(session, true)
      };
    }

    // 2. Tile is Gold / Diamond!
    session.revealedIndices.add(idx);
    const gemsRevealed = session.revealedIndices.size;
    const currentMult = calculateMinesMultiplier(session.mineCount, gemsRevealed);
    session.currentMultiplier = currentMult;
    session.wonAmount = Math.round(session.amount * currentMult);

    const totalGems = 25 - session.mineCount;
    const isAllGemsFound = gemsRevealed >= totalGems;

    let updatedWallet = null;

    if (isAllGemsFound) {
      // Auto cashout on finding all gems!
      session.status = 'cashed_out';
      updatedWallet = this._creditUserWinnings(userId, session.wonAmount);

      this._recordWinInDb(session);

      this.history.unshift({
        id: session.id,
        mineCount: session.mineCount,
        gemsRevealed,
        multiplier: currentMult,
        wonAmount: session.wonAmount,
        status: 'cashed_out',
        time: now
      });
      if (this.history.length > 25) this.history.pop();
    }

    return {
      success: true,
      status: session.status,
      isMine: false,
      tileIndex: idx,
      gemsRevealed,
      currentMultiplier: currentMult,
      wonAmount: session.wonAmount,
      nextMultiplier: isAllGemsFound ? null : calculateMinesMultiplier(session.mineCount, gemsRevealed + 1),
      allMines: isAllGemsFound ? Array.from(session.minePositions) : null,
      round: this._formatSession(session, isAllGemsFound),
      wallet: updatedWallet ? formatWallet(updatedWallet) : null
    };
  }

  // Cashout current winnings
  cashout({ userId, roundId }) {
    const session = this.sessions.get(roundId);
    if (!session || session.userId !== userId) {
      return { success: false, error: 'Game round not found' };
    }

    if (session.status !== 'active') {
      return { success: false, error: 'Game round is not active' };
    }

    if (session.revealedIndices.size === 0) {
      return { success: false, error: 'Must reveal at least one gold tile before cashout' };
    }

    const now = new Date().toISOString();
    session.status = 'cashed_out';
    const wonAmount = Math.round(session.amount * session.currentMultiplier);
    session.wonAmount = wonAmount;

    const updatedWallet = this._creditUserWinnings(userId, wonAmount);

    this._recordWinInDb(session);

    this.history.unshift({
      id: session.id,
      mineCount: session.mineCount,
      gemsRevealed: session.revealedIndices.size,
      multiplier: session.currentMultiplier,
      wonAmount,
      status: 'cashed_out',
      time: now
    });
    if (this.history.length > 25) this.history.pop();

    const allMines = Array.from(session.minePositions);

    return {
      success: true,
      message: `Cashed out ₹${wonAmount} at ${session.currentMultiplier}x!`,
      status: 'cashed_out',
      multiplier: session.currentMultiplier,
      wonAmount,
      allMines,
      round: this._formatSession(session, true),
      wallet: formatWallet(updatedWallet)
    };
  }

  // Record win in DB
  _recordWinInDb(session) {
    const now = new Date().toISOString();
    try {
      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_MINE_WIN_${session.id}`,
        session.userId,
        'prize_won',
        session.wonAmount,
        'completed',
        `Mines Gold Win @ ${session.currentMultiplier}x`,
        `Cashed out ₹${session.wonAmount} with ₹${session.amount} bet (${session.revealedIndices.size} gems found)`,
        now,
        session.id
      );

      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        `notif_mines_${Date.now()}`,
        session.userId,
        'Mines Gold Victory! 💎',
        `You won ₹${session.wonAmount} (${session.currentMultiplier}x multiplier)!`,
        'win',
        now,
        0
      );
    } catch (e) {
      console.error('[MinesEngine] DB win record error:', e);
    }
  }

  // Format session object for frontend
  _formatSession(session, showAll = false) {
    const gemsRevealed = session.revealedIndices.size;
    const isCompleted = session.status !== 'active';
    const shouldRevealAll = showAll || isCompleted;

    return {
      id: session.id,
      amount: session.amount,
      mineCount: session.mineCount,
      totalTiles: 25,
      revealedIndices: Array.from(session.revealedIndices),
      allMines: shouldRevealAll ? Array.from(session.minePositions) : null,
      gemsRevealed,
      currentMultiplier: session.currentMultiplier,
      wonAmount: session.wonAmount,
      nextMultiplier: (session.status === 'active' && gemsRevealed < 25 - session.mineCount)
        ? calculateMinesMultiplier(session.mineCount, gemsRevealed + 1)
        : null,
      status: session.status,
      hash: session.hash,
      serverSeed: shouldRevealAll ? session.serverSeed : null
    };
  }

  // Get Mines History
  getHistory() {
    return this.history.slice(0, 20);
  }

  // Get active session for user
  getUserActiveRound(userId) {
    for (const [_, s] of this.sessions.entries()) {
      if (s.userId === userId && s.status === 'active') {
        return this._formatSession(s);
      }
    }
    return null;
  }
}

const minesEngine = new MinesEngine();

module.exports = {
  minesEngine,
  calculateMinesMultiplier
};
