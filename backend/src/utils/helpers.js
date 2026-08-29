function formatUser(row) {
  if (!row) return null;
  let gameIds = {};
  let bankAccount = null;

  try {
    gameIds = typeof row.game_ids === 'string' ? JSON.parse(row.game_ids) : (row.game_ids || {});
  } catch (_) {
    gameIds = {};
  }

  try {
    bankAccount = typeof row.bank_account === 'string' && row.bank_account ? JSON.parse(row.bank_account) : null;
  } catch (_) {
    bankAccount = null;
  }

  return {
    id: row.id,
    username: row.username,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    avatarSeed: row.avatar_seed || row.username,
    kycStatus: row.kyc_status || 'not_submitted',
    kycDocumentType: row.kyc_document_type || null,
    kycDocumentNumber: row.kyc_document_number || null,
    gameIds: gameIds,
    joinedAt: row.joined_at,
    upiId: row.upi_id || null,
    bankAccount: bankAccount
  };
}

function formatWallet(row) {
  if (!row) {
    return {
      depositBalance: 0,
      winningBalance: 0,
      bonusBalance: 0
    };
  }
  return {
    depositBalance: Number(row.deposit_balance) || 0,
    winningBalance: Number(row.winning_balance) || 0,
    bonusBalance: Number(row.bonus_balance) || 0
  };
}

function formatArena(row, participants = []) {
  if (!row) return null;

  let rules = [];
  let prizeDistribution = [];

  try {
    rules = typeof row.rules === 'string' ? JSON.parse(row.rules) : (row.rules || []);
  } catch (_) {
    rules = [];
  }

  try {
    prizeDistribution = typeof row.prize_distribution === 'string' ? JSON.parse(row.prize_distribution) : (row.prize_distribution || []);
  } catch (_) {
    prizeDistribution = [];
  }

  const registeredPlayers = (participants || []).map(p => ({
    userId: p.user_id,
    username: p.username,
    inGameId: p.in_game_id,
    joinedAt: p.joined_at
  }));

  return {
    id: row.id,
    title: row.title,
    game: row.game,
    format: row.format,
    map: row.map,
    server: row.server,
    entryFee: Number(row.entry_fee) || 0,
    prizePool: Number(row.prize_pool) || 0,
    perKillPrize: Number(row.per_kill_prize) || 0,
    maxSlots: Number(row.max_slots) || 100,
    registeredPlayers: registeredPlayers,
    startTime: row.start_time,
    status: row.status || 'upcoming',
    roomId: row.room_id || null,
    roomPassword: row.room_password || null,
    rules: rules,
    prizeDistribution: prizeDistribution,
    winner: row.winner || null,
    createdBy: row.created_by
  };
}

function formatTransaction(row) {
  if (!row) return null;
  return {
    id: row.id,
    type: row.type,
    amount: Number(row.amount) || 0,
    status: row.status,
    title: row.title,
    description: row.description || '',
    timestamp: row.timestamp,
    referenceId: row.reference_id || null,
    paymentMethod: row.payment_method || null
  };
}

function formatWithdrawal(row) {
  if (!row) return null;
  return {
    id: row.id,
    amount: Number(row.amount) || 0,
    method: row.method,
    accountDetails: row.account_details,
    status: row.status,
    createdAt: row.created_at,
    processedAt: row.processed_at || null,
    txnReference: row.txn_reference || null
  };
}

function formatNotification(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    message: row.message,
    type: row.type || 'info',
    timestamp: row.timestamp,
    read: Boolean(row.read)
  };
}

module.exports = {
  formatUser,
  formatWallet,
  formatArena,
  formatTransaction,
  formatWithdrawal,
  formatNotification
};
