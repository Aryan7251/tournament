const { aviatorEngine } = require('../services/aviatorEngine');
const { minesEngine } = require('../services/minesEngine');
const { wheelEngine } = require('../services/wheelEngine');
const { diceEngine } = require('../services/diceEngine');
const { db } = require('../config/database');

// --- AVIATOR ROUTES ---

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

// --- MINES GOLD ROUTES ---

// POST /api/games/mines/start
exports.startMines = (req, res) => {
  try {
    const { userId, amount, mineCount } = req.body;
    if (!userId || !amount) {
      return res.status(400).json({ success: false, error: 'User ID and bet amount are required' });
    }

    const result = minesEngine.startGame({ userId, amount, mineCount });
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('startMines error:', error);
    return res.status(500).json({ success: false, error: 'Failed to start Mines game' });
  }
};

// POST /api/games/mines/reveal
exports.revealMinesTile = (req, res) => {
  try {
    const { userId, roundId, tileIndex } = req.body;
    if (!userId || !roundId || tileIndex === undefined) {
      return res.status(400).json({ success: false, error: 'User ID, round ID, and tile index are required' });
    }

    const result = minesEngine.revealTile({ userId, roundId, tileIndex });
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('revealMinesTile error:', error);
    return res.status(500).json({ success: false, error: 'Failed to reveal tile' });
  }
};

// POST /api/games/mines/cashout
exports.cashoutMines = (req, res) => {
  try {
    const { userId, roundId } = req.body;
    if (!userId || !roundId) {
      return res.status(400).json({ success: false, error: 'User ID and round ID are required' });
    }

    const result = minesEngine.cashout({ userId, roundId });
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('cashoutMines error:', error);
    return res.status(500).json({ success: false, error: 'Failed to cashout Mines game' });
  }
};

// GET /api/games/mines/state?userId=...
exports.getMinesState = (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }
    const activeRound = minesEngine.getUserActiveRound(userId);
    return res.json({
      success: true,
      data: activeRound
    });
  } catch (error) {
    console.error('getMinesState error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch Mines state' });
  }
};

// GET /api/games/mines/history
exports.getMinesHistory = (req, res) => {
  try {
    return res.json({
      success: true,
      data: minesEngine.getHistory()
    });
  } catch (error) {
    console.error('getMinesHistory error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch Mines history' });
  }
};

// --- LUCKY WHEEL ROUTES ---

// GET /api/games/wheel/segments?risk=...
exports.getWheelSegments = (req, res) => {
  try {
    const { risk } = req.query;
    return res.json({
      success: true,
      data: wheelEngine.getSegments(risk || 'medium')
    });
  } catch (error) {
    console.error('getWheelSegments error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch wheel segments' });
  }
};

// POST /api/games/wheel/spin
exports.spinWheel = (req, res) => {
  try {
    const { userId, amount, risk } = req.body;
    if (!userId || !amount) {
      return res.status(400).json({ success: false, error: 'User ID and bet amount are required' });
    }

    const result = wheelEngine.spin({ userId, amount, risk: risk || 'medium' });
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('spinWheel error:', error);
    return res.status(500).json({ success: false, error: 'Failed to spin wheel' });
  }
};

// GET /api/games/wheel/history
exports.getWheelHistory = (req, res) => {
  try {
    return res.json({
      success: true,
      data: wheelEngine.getHistory()
    });
  } catch (error) {
    console.error('getWheelHistory error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch wheel history' });
  }
};

// --- CYBER DICE ROUTES ---

// POST /api/games/dice/roll
exports.rollDice = (req, res) => {
  try {
    const { userId, amount, mode, target, condition, choice } = req.body;
    if (!userId || !amount) {
      return res.status(400).json({ success: false, error: 'User ID and bet amount are required' });
    }

    const result = diceEngine.roll({ userId, amount, mode, target, condition, choice });
    if (result.success) {
      return res.json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('rollDice error:', error);
    return res.status(500).json({ success: false, error: 'Failed to roll dice' });
  }
};

// GET /api/games/dice/history
exports.getDiceHistory = (req, res) => {
  try {
    return res.json({
      success: true,
      data: diceEngine.getHistory()
    });
  } catch (error) {
    console.error('getDiceHistory error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch dice history' });
  }
};

// --- GAMES CATALOG ---

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
        id: 'mines',
        name: 'Mines Gold',
        category: 'Grid Diamonds',
        description: 'Uncover sparkling diamonds and dodge hidden mines on a 5x5 grid with escalating multipliers!',
        banner: 'assets/games/mines.png',
        minBet: 10,
        maxBet: 5000,
        status: 'live',
        activePlayers: 240 + Math.floor(Math.random() * 30)
      },
      {
        id: 'wheel',
        name: 'Lucky Wheel',
        category: 'Spin & Win',
        description: 'Spin the neon lucky wheel with multiple risk modes to win up to 100x instant cash!',
        banner: 'assets/games/wheel.png',
        minBet: 10,
        maxBet: 5000,
        status: 'live',
        activePlayers: 195 + Math.floor(Math.random() * 25)
      },
      {
        id: 'dice',
        name: 'Cyber Dice',
        category: 'High / Low & Slider',
        description: 'Roll futuristic cyber dice with customizable win chances, multipliers, and dual dice sum betting!',
        banner: 'assets/games/dice.png',
        minBet: 10,
        maxBet: 5000,
        status: 'live',
        activePlayers: 160 + Math.floor(Math.random() * 20)
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
