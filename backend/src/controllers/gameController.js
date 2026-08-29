const { aviatorEngine } = require('../services/aviatorEngine');
const { db } = require('../config/database');

// GET /api/games/aviator/state?userId=...
exports.getAviatorState = (req, res) => {
  try {
    const { userId } = req.query;
    const state = aviatorEngine.getGameState(userId);
    return res.json({
      success: true,
      data: state
    });
  } catch (error) {
    console.error('getAviatorState error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch game state' });
  }
};

// POST /api/games/aviator/bet
exports.placeAviatorBet = (req, res) => {
  try {
    const { userId, slotNum, amount, autoCashoutEnabled, autoCashoutValue } = req.body;

    if (!userId || !amount) {
      return res.status(400).json({ success: false, error: 'User ID and bet amount are required' });
    }

    const result = aviatorEngine.placeBet({
      userId,
      slotNum: parseInt(slotNum, 10) || 1,
      amount: parseInt(amount, 10),
      autoCashoutEnabled: Boolean(autoCashoutEnabled),
      autoCashoutValue: parseFloat(autoCashoutValue) || 2.0
    });

    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('placeAviatorBet error:', error);
    return res.status(500).json({ success: false, error: 'Failed to place bet' });
  }
};

// POST /api/games/aviator/cancel-bet
exports.cancelAviatorBet = (req, res) => {
  try {
    const { userId, betId } = req.body;
    if (!userId || !betId) {
      return res.status(400).json({ success: false, error: 'User ID and bet ID are required' });
    }

    const result = aviatorEngine.cancelBet(userId, betId);
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('cancelAviatorBet error:', error);
    return res.status(500).json({ success: false, error: 'Failed to cancel bet' });
  }
};

// POST /api/games/aviator/cashout
exports.cashoutAviatorBet = (req, res) => {
  try {
    const { userId, betId } = req.body;
    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }

    const result = aviatorEngine.cashoutBet(userId, betId);
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('cashoutAviatorBet error:', error);
    return res.status(500).json({ success: false, error: 'Failed to cashout' });
  }
};

// GET /api/games/aviator/history
exports.getAviatorHistory = (req, res) => {
  try {
    const rounds = db.prepare(`
      SELECT id, crash_multiplier, server_seed, hash, created_at, crashed_at
      FROM game_rounds
      WHERE game_type = 'aviator' AND status = 'crashed'
      ORDER BY created_at DESC
      LIMIT 30
    `).all();

    return res.json({
      success: true,
      data: rounds.map(r => ({
        id: r.id,
        multiplier: r.crash_multiplier,
        hash: r.hash,
        time: r.crashed_at || r.created_at
      }))
    });
  } catch (error) {
    console.error('getAviatorHistory error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch history' });
  }
};

// GET /api/games/catalog
exports.getGameCatalog = (req, res) => {
  try {
    const catalog = [
      {
        id: 'aviator',
        name: 'Aviator Crash',
        category: 'Instant Win / Crash',
        description: 'Watch the plane soar and cash out before it flies away! Multipliers up to 100x+.',
        banner: 'assets/games/aviator.png',
        minBet: 10,
        maxBet: 5000,
        status: 'live',
        activePlayers: 184 + Math.floor(Math.random() * 40)
      },
      {
        id: 'bgmi',
        name: 'BGMI Battle Royale',
        category: 'Esports Tournament',
        description: 'Custom Room Solo, Duo & Squad tournaments with per-kill bounties and grand prize pools.',
        status: 'live',
        activePlayers: 420 + Math.floor(Math.random() * 50)
      },
      {
        id: 'freefire',
        name: 'Free Fire MAX',
        category: 'Esports Tournament',
        description: 'Battle in Bermuda & Purgatory with daily custom clash squads and cash rewards.',
        status: 'live',
        activePlayers: 310 + Math.floor(Math.random() * 30)
      },
      {
        id: 'codm',
        name: 'Call of Duty: Mobile',
        category: 'Esports Tournament',
        description: 'Multiplayer and Battle Royale tournaments with instant prize payouts.',
        status: 'live',
        activePlayers: 150 + Math.floor(Math.random() * 20)
      },
      {
        id: 'ludo',
        name: 'Ludo King Arena',
        category: 'Board Game',
        description: '1v1 Quick Ludo King cash challenges with verified room codes.',
        status: 'live',
        activePlayers: 290 + Math.floor(Math.random() * 35)
      },
      {
        id: 'chess',
        name: 'Speed Chess',
        category: 'Strategy',
        description: '5-minute blitz and rapid chess matches with ELO-based matchmaking.',
        status: 'live',
        activePlayers: 95 + Math.floor(Math.random() * 15)
      }
    ];

    return res.json({
      success: true,
      data: catalog
    });
  } catch (error) {
    console.error('getGameCatalog error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch games catalog' });
  }
};
