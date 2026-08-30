const crypto = require('crypto');
const Razorpay = require('razorpay');
const { db } = require('../config/database');
const { formatWallet } = require('../utils/helpers');

function getSetting(key, defVal) {
  try {
    const row = db.prepare('SELECT value FROM system_settings WHERE key = ?').get(key);
    return row ? row.value : defVal;
  } catch (_) {
    return defVal;
  }
}

function getRazorpayInstance() {
  const keyId = getSetting('razorpay_key_id', process.env.RAZORPAY_KEY_ID || 'rzp_test_YOUR_KEY_ID');
  const keySecret = getSetting('razorpay_key_secret', process.env.RAZORPAY_KEY_SECRET || '');
  
  if (!keyId || !keySecret || keyId === 'rzp_test_YOUR_KEY_ID') {
    return { instance: null, keyId, keySecret, isConfigured: false };
  }

  try {
    const instance = new Razorpay({
      key_id: keyId,
      key_secret: keySecret
    });
    return { instance, keyId, keySecret, isConfigured: true };
  } catch (err) {
    console.error('Failed to initialize Razorpay client:', err);
    return { instance: null, keyId, keySecret, isConfigured: false };
  }
}

// GET /api/wallet/razorpay/config (Public)
exports.getRazorpayConfig = (req, res) => {
  try {
    const enabled = getSetting('razorpay_enabled', 'true') === 'true';
    const keyId = getSetting('razorpay_key_id', 'rzp_test_YOUR_KEY_ID');
    const keySecret = getSetting('razorpay_key_secret', '');
    const mode = getSetting('razorpay_mode', 'test');
    const minDeposit = parseInt(getSetting('min_deposit', '50'), 10);
    const maxDeposit = parseInt(getSetting('max_deposit', '50000'), 10);

    const isConfigured = Boolean(
      enabled &&
      keyId &&
      keyId !== 'rzp_test_YOUR_KEY_ID' &&
      keyId.length > 5 &&
      keySecret &&
      keySecret.length > 5
    );

    return res.json({
      success: true,
      data: {
        enabled,
        keyId: isConfigured ? keyId : null,
        mode,
        minDeposit,
        maxDeposit,
        isConfigured
      }
    });
  } catch (error) {
    console.error('getRazorpayConfig error:', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch Razorpay configuration' });
  }
};

// POST /api/wallet/:userId/razorpay/create-order
exports.createRazorpayOrder = async (req, res) => {
  try {
    const { userId } = req.params;
    const { amount } = req.body;

    const enabled = getSetting('razorpay_enabled', 'true') === 'true';
    if (!enabled) {
      return res.status(400).json({
        success: false,
        error: 'Payment option is currently not available. Razorpay gateway is disabled.'
      });
    }

    const { instance, keyId, isConfigured } = getRazorpayInstance();
    if (!isConfigured || !instance) {
      return res.status(400).json({
        success: false,
        error: 'Payment option is not available. Razorpay API keys have not been configured in the Admin Panel yet.'
      });
    }

    const minDeposit = parseInt(getSetting('min_deposit', '50'), 10);
    const maxDeposit = parseInt(getSetting('max_deposit', '50000'), 10);

    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount < minDeposit) {
      return res.status(400).json({ success: false, error: `Minimum deposit amount is ₹${minDeposit}` });
    }

    if (numAmount > maxDeposit) {
      return res.status(400).json({
        success: false,
        error: `Deposit amount exceeds maximum limit of ₹${maxDeposit.toLocaleString('en-IN')}`
      });
    }

    // Check user
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Check daily limit
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayIso = todayStart.toISOString();

    const todayDeposits = db.prepare(`
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE user_id = ? AND type = 'deposit' AND timestamp >= ? AND status = 'completed'
    `).get(userId, todayIso);

    const currentDailyTotal = todayDeposits ? todayDeposits.total : 0;
    if (currentDailyTotal + numAmount > maxDeposit) {
      const remaining = Math.max(0, maxDeposit - currentDailyTotal);
      return res.status(400).json({
        success: false,
        error: `Daily deposit limit of ₹${maxDeposit.toLocaleString('en-IN')} reached for today. Remaining limit: ₹${remaining.toLocaleString('en-IN')}.`
      });
    }

    const receiptId = `rcpt_${Date.now()}_${userId.slice(-4)}`;
    const amountInPaise = numAmount * 100;

    let order;
    try {
      order = await instance.orders.create({
        amount: amountInPaise,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          userId: userId,
          username: user.username
        }
      });
    } catch (rzpErr) {
      console.error('Razorpay API order creation error:', rzpErr);
      return res.status(400).json({
        success: false,
        error: `Razorpay Error: ${rzpErr.error ? rzpErr.error.description || rzpErr.error.code : rzpErr.message || 'Failed to create order on Razorpay'}`
      });
    }

    return res.json({
      success: true,
      data: {
        orderId: order.id,
        amount: numAmount,
        amountInPaise,
        currency: 'INR',
        keyId,
        isConfigured: true,
        receipt: receiptId,
        customer: {
          name: user.full_name || user.username,
          email: user.email,
          contact: user.phone
        }
      }
    });
  } catch (error) {
    console.error('createRazorpayOrder error:', error);
    return res.status(500).json({ success: false, error: 'Failed to initiate Razorpay order' });
  }
};

// POST /api/wallet/:userId/razorpay/verify
exports.verifyRazorpayPayment = async (req, res) => {
  try {
    const { userId } = req.params;
    const { razorpay_payment_id, razorpay_order_id, razorpay_signature, amount } = req.body;

    const { instance, keySecret, isConfigured } = getRazorpayInstance();
    if (!isConfigured || !keySecret) {
      return res.status(400).json({
        success: false,
        error: 'Payment option is not available. Razorpay gateway is not configured.'
      });
    }

    if (!razorpay_payment_id || !razorpay_order_id || !razorpay_signature) {
      return res.status(400).json({ success: false, error: 'Payment ID, Order ID and Signature are required' });
    }

    // Check for duplicate transaction (idempotency)
    const existingTxn = db.prepare('SELECT id FROM transactions WHERE reference_id = ?').get(razorpay_payment_id);
    if (existingTxn) {
      const currentWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
      return res.json({
        success: true,
        message: 'Payment already verified and credited',
        data: formatWallet(currentWallet)
      });
    }

    // Verify HMAC-SHA256 signature using timing-safe comparison
    const generatedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    const sigBufferA = Buffer.from(generatedSignature, 'utf8');
    const sigBufferB = Buffer.from(String(razorpay_signature), 'utf8');

    if (sigBufferA.length !== sigBufferB.length || !crypto.timingSafeEqual(sigBufferA, sigBufferB)) {
      return res.status(400).json({
        success: false,
        error: 'Razorpay payment signature verification failed. Untrusted transaction.'
      });
    }

    // Authoritatively verify amount and user from server-side order
    let verifiedAmount = parseInt(amount, 10);
    if (instance) {
      try {
        const orderData = await instance.orders.fetch(razorpay_order_id);
        if (orderData && orderData.amount) {
          const serverAmount = Math.floor(orderData.amount / 100);
          if (serverAmount > 0) {
            verifiedAmount = serverAmount;
          }
          if (orderData.notes && orderData.notes.userId && orderData.notes.userId !== userId) {
            return res.status(403).json({
              success: false,
              error: 'Order ownership mismatch. Transaction rejected.'
            });
          }
        }
      } catch (orderErr) {
        console.warn('[Razorpay] Order fetch notice:', orderErr.message);
      }
    }

    if (isNaN(verifiedAmount) || verifiedAmount <= 0) {
      return res.status(400).json({ success: false, error: 'Invalid deposit amount' });
    }

    // Ensure wallet exists
    let wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    const now = new Date().toISOString();

    if (!wallet) {
      db.prepare(`
        INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
        VALUES (?, 0, 0, 0, ?)
      `).run(userId, now);
      wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    }

    const newDeposit = wallet.deposit_balance + verifiedAmount;

    db.prepare(`
      UPDATE wallets
      SET deposit_balance = ?, updated_at = ?
      WHERE user_id = ?
    `).run(newDeposit, now, userId);

    const txnId = `TXN_RZP_${Date.now()}`;

    // Record Transaction
    db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      txnId,
      userId,
      'deposit',
      verifiedAmount,
      'completed',
      'Added Cash to Wallet',
      `Payment via Razorpay (${razorpay_payment_id})`,
      now,
      razorpay_payment_id,
      'Razorpay'
    );

    // Record Notification
    db.prepare(`
      INSERT INTO notifications (
        id, user_id, title, message, type, timestamp, read
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Razorpay Deposit Successful! 💳',
      `₹${verifiedAmount} deposited into your wallet via Razorpay. Payment ID: ${razorpay_payment_id}`,
      'success',
      now,
      0
    );

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return res.json({
      success: true,
      message: `₹${verifiedAmount} successfully added to wallet via Razorpay`,
      data: formatWallet(updatedWallet),
      paymentId: razorpay_payment_id
    });
  } catch (error) {
    console.error('verifyRazorpayPayment error:', error);
    return res.status(500).json({ success: false, error: 'Razorpay payment verification failed' });
  }
};

// POST /api/wallet/razorpay/webhook
exports.razorpayWebhook = async (req, res) => {
  try {
    const webhookSecret = getSetting('razorpay_webhook_secret', '');
    const signature = req.headers['x-razorpay-signature'];

    if (webhookSecret) {
      if (!signature) {
        return res.status(400).json({ success: false, error: 'Missing webhook signature header' });
      }

      const payload = JSON.stringify(req.body);
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(payload)
        .digest('hex');

      const sigA = Buffer.from(expectedSignature, 'utf8');
      const sigB = Buffer.from(String(signature), 'utf8');

      if (sigA.length !== sigB.length || !crypto.timingSafeEqual(sigA, sigB)) {
        return res.status(400).json({ success: false, error: 'Invalid webhook signature' });
      }
    }

    const event = req.body.event;
    if (event === 'payment.captured' || event === 'order.paid') {
      const payment = req.body.payload?.payment?.entity;
      if (payment && payment.notes && payment.notes.userId) {
        const userId = payment.notes.userId;
        const paymentId = payment.id;
        const amount = Math.floor(payment.amount / 100);

        if (amount > 0) {
          const existing = db.prepare('SELECT id FROM transactions WHERE reference_id = ?').get(paymentId);
          if (!existing) {
            const now = new Date().toISOString();
            let wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
            if (!wallet) {
              db.prepare('INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at) VALUES (?, 0, 0, 0, ?)').run(userId, now);
              wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
            }

            db.prepare('UPDATE wallets SET deposit_balance = deposit_balance + ?, updated_at = ? WHERE user_id = ?').run(amount, now, userId);
            db.prepare(`
              INSERT INTO transactions (id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method)
              VALUES (?, ?, 'deposit', ?, 'completed', 'Razorpay Auto-Credit (Webhook)', ?, ?, ?, 'Razorpay')
            `).run(`TXN_RZP_WH_${Date.now()}`, userId, amount, `Webhook capture for ${paymentId}`, now, paymentId);
          }
        }
      }
    }

    return res.json({ status: 'ok' });
  } catch (err) {
    console.error('Razorpay webhook error:', err);
    return res.status(500).json({ error: 'Webhook processing failed' });
  }
};

// Legacy / Direct deposit fallback
exports.depositFunds = (req, res) => {
  try {
    const { userId } = req.params;
    const { amount, method, promoCode, utr } = req.body;

    const minDeposit = parseInt(getSetting('min_deposit', '50'), 10);
    const maxDeposit = parseInt(getSetting('max_deposit', '50000'), 10);

    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount < minDeposit) {
      return res.status(400).json({ success: false, error: `Minimum deposit amount is ₹${minDeposit}` });
    }

    if (numAmount > maxDeposit) {
      return res.status(400).json({
        success: false,
        error: `Deposit amount exceeds maximum limit of ₹${maxDeposit.toLocaleString('en-IN')}`
      });
    }

    let wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    const now = new Date().toISOString();

    if (!wallet) {
      db.prepare(`
        INSERT INTO wallets (user_id, deposit_balance, winning_balance, bonus_balance, updated_at)
        VALUES (?, 0, 0, 0, ?)
      `).run(userId, now);
      wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    }

    let bonus = 0;
    if (promoCode && typeof promoCode === 'string') {
      const code = promoCode.toUpperCase().trim();
      if (code === 'LUCKY100') {
        bonus = Math.round(numAmount * 0.2);
      } else if (code === 'FIRSTWIN') {
        bonus = 50;
      }
    }

    const newDeposit = wallet.deposit_balance + numAmount;
    const newBonus = wallet.bonus_balance + bonus;

    db.prepare(`
      UPDATE wallets
      SET deposit_balance = ?, bonus_balance = ?, updated_at = ?
      WHERE user_id = ?
    `).run(newDeposit, newBonus, now, userId);

    const paymentMethod = method || 'Razorpay Gateway';
    const txnId = `TXN_DEP_${Date.now()}`;
    const refId = utr || `REF${Date.now()}`;

    // Record Transaction
    db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      txnId,
      userId,
      'deposit',
      numAmount,
      'completed',
      'Added Cash to Wallet',
      `Payment via ${paymentMethod}${bonus > 0 ? ` (+₹${bonus} Bonus)` : ''}`,
      now,
      refId,
      paymentMethod
    );

    // Record Notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Deposit Successful',
      `₹${numAmount} has been added to your deposit balance.${bonus > 0 ? ` Received ₹${bonus} bonus cash!` : ''}`,
      'success',
      now,
      0
    );

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return res.json({
      success: true,
      message: `Deposit of ₹${numAmount} completed`,
      data: formatWallet(updatedWallet)
    });
  } catch (error) {
    console.error('Deposit error:', error);
    return res.status(500).json({ success: false, error: 'Deposit transaction failed' });
  }
};

exports.withdrawFunds = (req, res) => {
  try {
    const { userId } = req.params;
    const { amount, method, details } = req.body;

    const minWithdrawal = parseInt(getSetting('min_withdrawal', '50'), 10);
    const maxWithdrawal = parseInt(getSetting('max_withdrawal', '100000'), 10);

    const numAmount = parseInt(amount, 10);
    if (isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({ success: false, error: 'Please enter a valid withdrawal amount' });
    }

    if (numAmount < minWithdrawal) {
      return res.status(400).json({ success: false, error: `Minimum withdrawal amount is ₹${minWithdrawal}` });
    }

    if (numAmount > maxWithdrawal) {
      return res.status(400).json({ success: false, error: `Maximum withdrawal limit is ₹${maxWithdrawal.toLocaleString('en-IN')}` });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    if (user.kyc_status !== 'verified') {
      return res.status(400).json({
        success: false,
        error: 'KYC verification is required before initiating withdrawals.'
      });
    }

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);
    if (!wallet || wallet.winning_balance < numAmount) {
      return res.status(400).json({
        success: false,
        error: `Insufficient withdrawable winnings balance (Available: ₹${wallet ? wallet.winning_balance : 0})`
      });
    }

    const now = new Date().toISOString();
    const newWinning = wallet.winning_balance - numAmount;

    db.prepare(`
      UPDATE wallets
      SET winning_balance = ?, updated_at = ?
      WHERE user_id = ?
    `).run(newWinning, now, userId);

    const wthId = `WTH_${Date.now()}`;
    const txnRef = `UTR${Date.now()}`;
    const methodStr = (method || 'upi').toLowerCase();
    const accountDetails = details || user.upi_id || 'Account';

    // Insert Withdrawal Request with initial 'requested' status (4h hold before processing)
    db.prepare(`
      INSERT INTO withdrawal_requests (
        id, user_id, amount, method, account_details, status, created_at, processed_at, txn_reference
      ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)
    `).run(
      wthId,
      userId,
      numAmount,
      methodStr,
      accountDetails,
      'requested',
      now,
      txnRef
    );

    // Insert Transaction with 'pending' status
    db.prepare(`
      INSERT INTO transactions (
        id, user_id, type, amount, status, title, description, timestamp, reference_id, payment_method
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      `TXN_${wthId}`,
      userId,
      'withdrawal',
      numAmount,
      'pending',
      'Withdrawal Request (4h Hold)',
      `Requested via ${methodStr.toUpperCase()} to ${accountDetails}. Security hold active — bank dispatch begins in 4 hours.`,
      now,
      txnRef,
      methodStr.toUpperCase()
    );

    // Insert Notification
    db.prepare(`
      INSERT INTO notifications (id, user_id, title, message, type, timestamp, read)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      `notif_${Date.now()}`,
      userId,
      'Withdrawal Requested 🕒',
      `₹${numAmount} withdrawal request registered. Security verification hold active — processing begins in 4 hours.`,
      'info',
      now,
      0
    );

    const updatedWallet = db.prepare('SELECT * FROM wallets WHERE user_id = ?').get(userId);

    return res.json({
      success: true,
      message: `Withdrawal of ₹${numAmount} requested successfully. Status: REQUESTED (Processing begins in 4 hours).`,
      data: formatWallet(updatedWallet)
    });
  } catch (error) {
    console.error('Withdrawal error:', error);
    return res.status(500).json({ success: false, error: 'Withdrawal processing failed' });
  }
};
