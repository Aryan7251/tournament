const { db } = require('../config/database');
const { formatArena } = require('../utils/helpers');

function getArenaWithParticipants(arenaId) {
  const arenaRow = db.prepare('SELECT * FROM arenas WHERE id = ?').get(arenaId);
  if (!arenaRow) return null;
  const participants = db.prepare('SELECT * FROM arena_participants WHERE arena_id = ?').all(arenaId);
  return formatArena(arenaRow, participants);
}

exports.getArenas = (req, res) => {
  try {
    const arenas = db.prepare('SELECT * FROM arenas ORDER BY created_at DESC').all();
    const result = arenas.map(a => {
      const participants = db.prepare('SELECT * FROM arena_participants WHERE arena_id = ?').all(a.id);
      return formatArena(a, participants);
    });

    return res.json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Get arenas error:', error);
    return res.status(500).json({ success: false, error: 'Failed to retrieve arenas' });
  }
};

exports.createArena = (req, res) => {
  try {
    const {
      userId,
      title,
      game,
      format,
      map,
      server,
      entryFee,
      prizePool,
      perKillPrize,
      maxSlots,
      startTime,
      roomId,
      roomPassword,
      rules
    } = req.body;

    if (!title || !game) {
      return res.status(400).json({ success: false, error: 'Title and game are required' });
    }

    const arenaId = `arena_${Date.now()}`;
    const now = new Date().toISOString();
    const finalPrizePool = parseInt(prizePool, 10) || 0;
    const finalEntryFee = parseInt(entryFee, 10) || 0;
    const finalMaxSlots = parseInt(maxSlots, 10) || 100;
    const finalPerKill = parseInt(perKillPrize, 10) || 0;

    const prize1 = Math.round(finalPrizePool * 0.5);
    const prize2 = Math.round(finalPrizePool * 0.3);
    const prize3 = Math.round(finalPrizePool * 0.2);

    const prizeDistribution = [
      { rank: '1st Place (Winner)', amount: prize1 },
      { rank: '2nd Place', amount: prize2 },
      { rank: '3rd Place', amount: prize3 }
    ];

    const defaultRules = [
      'Emulators/Cheats will lead to an immediate ban.',
      'Room ID & Password will be revealed 15 minutes before match start.',
      'Submit screenshot of final match results to claim winning prizes.',
      'Fair play guidelines must be respected by all participants.'
    ];

    const generatedRoomId = roomId && roomId.trim() ? roomId.trim() : `ROOM_${Math.floor(100000 + Math.random() * 900000)}`;
    const generatedPassword = roomPassword && roomPassword.trim() ? roomPassword.trim() : `PASS_${Math.floor(1000 + Math.random() * 9000)}`;

    db.prepare(`
      INSERT INTO arenas (
        id, title, game, format, map, server, entry_fee, prize_pool,
        per_kill_prize, max_slots, start_time, status, room_id, room_password,
        rules, prize_distribution, winner, created_by, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      arenaId,
      title.trim(),
      game.trim(),
      format || 'Squad',
      map || 'Default Map',
      server || 'Asia',
      finalEntryFee,
      finalPrizePool,
      finalPerKill,
      finalMaxSlots,
      startTime || new Date(Date.now() + 2 * 3600000).toISOString(),
      'upcoming',
      generatedRoomId,
      generatedPassword,
      JSON.stringify(rules && rules.length > 0 ? rules : defaultRules),
      JSON.stringify(prizeDistribution),
      null,
      userId || 'official',
      now
    );

    // Notify creator
    if (userId) {
      db.prepare(`
        INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        `notif_${Date.now()}`,
        userId,
        'Arena Created',
        `"${title}" has been published and is open for registrations.`,
        'success',
        now,
        0
      );
    }

    const created = getArenaWithParticipants(arenaId);

    return res.json({
      success: true,
      message: 'Arena created successfully',
      data: created
    });
  } catch (error) {
    console.error('Create arena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to create tournament arena' });
  }
};

exports.joinArena = (req, res) => {
  try {
    const { arenaId } = req.params;
    const { userId, inGameId } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }

    const arena = db.prepare('SELECT * FROM arenas WHERE id = ?').get(arenaId);
    if (!arena) {
      return res.status(404).json({ success: false, error: 'Arena not found' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Check if already joined
    const existing = db.prepare('SELECT * FROM arena_participants WHERE arena_id = ? AND user_id = ?')
      .get(arenaId, userId);
    if (existing) {
      return res.status(400).json({ success: false, error: 'You have already joined this arena.' });
    }

    // Check slots
    const currentCount = db.prepare('SELECT COUNT(*) as count FROM arena_participants WHERE arena_id = ?')
      .get(arenaId).count;
    if (currentCount >= arena.max_slots) {
      return res.status(400).json({ success: false, error: 'Arena slots are already full.' });
    }

    // Check wallet balance
    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    const totalAvailable = (wallet ? wallet.deposit_balance : 0) + (wallet ? wallet.winning_balance : 0);

    if (arena.entry_fee > totalAvailable) {
      return res.status(400).json({
        success: false,
        error: `Insufficient funds (Entry fee ₹${arena.entry_fee}, Available: ₹${totalAvailable}). Please deposit cash.`
      });
    }

    const now = new Date().toISOString();

    // Deduct entry fee
    if (arena.entry_fee > 0 && wallet) {
      let rem = arena.entry_fee;
      let newDeposit = wallet.deposit_balance;
      let newWinning = wallet.winning_balance;

      if (newDeposit >= rem) {
        newDeposit -= rem;
        rem = 0;
      } else {
        rem -= newDeposit;
        newDeposit = 0;
        newWinning -= rem;
      }

      db.prepare(`
        UPDATE wallets
        SET deposit_balance = ?, winning_balance = ?, updated_at = ?
        WHERE user_id = ?
      `).run(newDeposit, newWinning, now, userId);

      // Add transaction
      db.prepare(`
        INSERT INTO transactions (
          id, user_id, type, amount, status, title, description, timestamp, reference_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        `TXN_JOIN_${Date.now()}`,
        userId,
        'entry_fee',
        arena.entry_fee,
        'completed',
        `Joined: ${arena.title}`,
        `Entry fee for ${arena.game} (${arena.format})`,
        now,
        arena.id
      );
    }

    // Get final in-game ID
    let finalInGameId = inGameId;
    if (!finalInGameId) {
      try {
        const gIds = JSON.parse(user.game_ids || '{}');
        finalInGameId = gIds[arena.game] || user.username;
      } catch (_) {
        finalInGameId = user.username;
      }
    }

    // Add participant
    db.prepare(`
      INSERT INTO arena_participants (arena_id, user_id, username, in_game_id, joined_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(arenaId, userId, user.username, finalInGameId, now);

    // Notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Joined Arena!',
      `Successfully registered for "${arena.title}". Room details unlock before match starts.`,
      'success',
      now,
      0
    );

    const updatedArena = getArenaWithParticipants(arenaId);

    return res.json({
      success: true,
      message: `Successfully registered for "${arena.title}"!`,
      data: updatedArena
    });
  } catch (error) {
    console.error('Join arena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to join arena' });
  }
};

exports.leaveArena = (req, res) => {
  try {
    const { arenaId } = req.params;
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }

    const arena = db.prepare('SELECT * FROM arenas WHERE id = ?').get(arenaId);
    if (!arena) {
      return res.status(404).json({ success: false, error: 'Arena not found' });
    }

    const participant = db.prepare('SELECT * FROM arena_participants WHERE arena_id = ? AND user_id = ?')
      .get(arenaId, userId);
    if (!participant) {
      return res.status(400).json({ success: false, error: 'You are not registered in this arena.' });
    }

    const now = new Date().toISOString();

    // Remove participant
    db.prepare('DELETE FROM arena_participants WHERE arena_id = ? AND user_id = ?')
      .run(arenaId, userId);

    // Refund entry fee if any
    if (arena.entry_fee > 0) {
      const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      if (wallet) {
        db.prepare(`
          UPDATE wallets
          SET deposit_balance = deposit_balance + ?, updated_at = ?
          WHERE user_id = ?
        `).run(arena.entry_fee, now, userId);

        db.prepare(`
          INSERT INTO transactions (
            id, user_id, type, amount, status, title, description, timestamp, reference_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          `TXN_REF_${Date.now()}`,
          userId,
          'refund',
          arena.entry_fee,
          'completed',
          `Refund: ${arena.title}`,
          'Arena entry fee refunded to deposit balance',
          now,
          arena.id
        );
      }
    }

    // Notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Registration Cancelled',
      `You left "${arena.title}". Entry fee has been refunded.`,
      'info',
      now,
      0
    );

    const updatedArena = getArenaWithParticipants(arenaId);

    return res.json({
      success: true,
      message: 'Registration cancelled and refunded.',
      data: updatedArena
    });
  } catch (error) {
    console.error('Leave arena error:', error);
    return res.status(500).json({ success: false, error: 'Failed to leave arena' });
  }
};

exports.claimPrizeWin = (req, res) => {
  try {
    const { arenaId } = req.params;
    const { userId, amount } = req.body;

    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid prize amount' });
    }

    const arena = db.prepare('SELECT * FROM arenas WHERE id = ?').get(arenaId);
    const now = new Date().toISOString();

    // Credit to winning balance
    db.prepare(`
      UPDATE wallets
      SET winning_balance = winning_balance + ?, updated_at = ?
      WHERE user_id = ?
    `).run(numAmount, now, userId);

    // Record prize win transaction
    db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      `TXN_WIN_${Date.now()}`,
      userId,
      'prize_won',
      numAmount,
      'completed',
      `Prize Won: ${arena ? arena.title : 'Arena Match'}`,
      'Match victory reward credited to Winnings balance',
      now,
      arenaId
    );

    // Record Notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Victory! Prize Credited',
      `Congratulations! ₹${numAmount} won from arena match has been credited to your withdrawable balance.`,
      'win',
      now,
      0
    );

    return res.json({
      success: true,
      message: `₹${numAmount} prize claimed and credited.`
    });
  } catch (error) {
    console.error('Claim prize win error:', error);
    return res.status(500).json({ success: false, error: 'Failed to claim prize win' });
  }
};
