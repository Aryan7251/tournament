import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/arena.dart';
import '../models/user_profile.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/withdrawal_request.dart';
import '../models/notification_item.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  static const String _prefUserKey = 'luckywin_user_clean_v5';
  static const String _prefWalletKey = 'luckywin_wallet_clean_v5';
  static const String _prefArenasKey = 'luckywin_arenas_clean_v5';
  static const String _prefTransactionsKey = 'luckywin_transactions_clean_v5';
  static const String _prefWithdrawalsKey = 'luckywin_withdrawals_clean_v5';
  static const String _prefNotificationsKey = 'luckywin_notifications_clean_v5';
  static const String _prefIsLoggedInKey = 'luckywin_is_authenticated_v1';

  Timer? _liveSyncTimer;

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  void setSelectedTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  late UserProfile _user;
  UserProfile get user => _user;

  late Wallet _wallet;
  Wallet get wallet => _wallet;

  late List<Arena> _arenas;
  List<Arena> get arenas => _arenas;

  late List<Transaction> _transactions;
  List<Transaction> get transactions => _transactions;

  late List<WithdrawalRequest> _withdrawals;
  List<WithdrawalRequest> get withdrawals => _withdrawals;

  late List<NotificationItem> _notifications;
  List<NotificationItem> get notifications => _notifications;

  int _minDeposit = 50;
  int get minDeposit => _minDeposit;

  int _minWithdrawal = 50;
  int get minWithdrawal => _minWithdrawal;

  int _maxDeposit = 50000;
  int get maxDeposit => _maxDeposit;

  int _maxWithdrawal = 100000;
  int get maxWithdrawal => _maxWithdrawal;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.read).length;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> ensureInitialized() => _initCompleter.isCompleted ? Future.value() : _initCompleter.future;

  bool _isServerConnected = false;
  bool get isServerConnected => _isServerConnected;

  AppProvider() {
    _initDefaults();
    _loadFromStorage();
    _startLiveSyncTimer();
  }

  void _startLiveSyncTimer() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (_isLoggedIn) {
        syncWithDatabase();
      }
    });
  }

  void _initDefaults() {
    _user = UserProfile(
      id: 'usr_default_player1',
      username: 'Player1',
      fullName: 'Player Account',
      email: 'player1@gamingarena.com',
      phone: '+91 9876543210',
      avatarSeed: 'Player1',
      kycStatus: KycStatus.notSubmitted,
      gameIds: {},
      joinedAt: DateTime.now().toIso8601String(),
    );

    _wallet = Wallet(
      depositBalance: 500,
      winningBalance: 250,
      bonusBalance: 100,
    );

    _arenas = [];
    _transactions = [];
    _withdrawals = [];
    _notifications = [];
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedLoggedIn = prefs.getBool(_prefIsLoggedInKey);

      final userStr = prefs.getString(_prefUserKey);
      if (userStr != null) {
        try {
          final loadedUser = UserProfile.fromJson(jsonDecode(userStr));
          _user = loadedUser;
          // If a saved user profile exists and not logged out, maintain login
          if (savedLoggedIn != false && loadedUser.id.isNotEmpty) {
            _isLoggedIn = true;
          } else {
            _isLoggedIn = savedLoggedIn ?? false;
          }
        } catch (e) {
          debugPrint('Error parsing stored user: $e');
          _isLoggedIn = savedLoggedIn ?? false;
        }
      } else {
        _isLoggedIn = savedLoggedIn ?? false;
      }

      final walletStr = prefs.getString(_prefWalletKey);
      if (walletStr != null) {
        _wallet = Wallet.fromJson(jsonDecode(walletStr));
      }

      final arenaStr = prefs.getString(_prefArenasKey);
      if (arenaStr != null) {
        final list = jsonDecode(arenaStr) as List<dynamic>;
        _arenas = list.map((e) => Arena.fromJson(e)).toList();
      }

      final txnStr = prefs.getString(_prefTransactionsKey);
      if (txnStr != null) {
        final list = jsonDecode(txnStr) as List<dynamic>;
        _transactions = list.map((e) => Transaction.fromJson(e)).toList();
      }

      final wthStr = prefs.getString(_prefWithdrawalsKey);
      if (wthStr != null) {
        final list = jsonDecode(wthStr) as List<dynamic>;
        _withdrawals =
            list.map((e) => WithdrawalRequest.fromJson(e)).toList();
      }

      final notifStr = prefs.getString(_prefNotificationsKey);
      if (notifStr != null) {
        final list = jsonDecode(notifStr) as List<dynamic>;
        _notifications =
            list.map((e) => NotificationItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading from storage: $e');
    } finally {
      _isInitialized = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      notifyListeners();
      if (_isLoggedIn) {
        syncWithDatabase();
      }
    }
  }

  Future<({bool success, String message})> loginUser(
    String identifier,
    String password,
  ) async {
    final res = await ApiService.login(identifier, password);
    if (res.success && res.user != null) {
      _user = res.user!;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedInKey, true);
      await _saveToStorage();

      await syncWithDatabase();
      notifyListeners();
      return (success: true, message: res.message);
    } else {
      return (success: false, message: res.message);
    }
  }

  Future<({bool success, String message})> registerUser({
    required String username,
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await ApiService.register(
      username: username,
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );
    if (res.success && res.user != null) {
      _user = res.user!;
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedInKey, true);
      await _saveToStorage();

      await syncWithDatabase();
      notifyListeners();
      return (success: true, message: res.message);
    } else {
      return (success: false, message: res.message);
    }
  }

  Future<void> logoutUser() async {
    _isLoggedIn = false;
    _selectedTabIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsLoggedInKey, false);
    await prefs.remove(_prefUserKey);
    await prefs.remove(_prefWalletKey);
    await prefs.remove(_prefTransactionsKey);
    await prefs.remove(_prefWithdrawalsKey);
    await prefs.remove(_prefNotificationsKey);
    _initDefaults();
    notifyListeners();
  }

  Future<void> syncWithDatabase() async {
    try {
      final isAvailable = await ApiService.isServerAvailable();
      _isServerConnected = isAvailable;

      if (isAvailable) {
        final syncData = await ApiService.fetchFullSync(_user.id);
        if (syncData != null) {
          bool hasChanges = false;

          if (syncData.user != null &&
              (_user.kycStatus != syncData.user!.kycStatus ||
                  _user.username != syncData.user!.username ||
                  _user.upiId != syncData.user!.upiId ||
                  _user.bankAccount != syncData.user!.bankAccount)) {
            _user = syncData.user!;
            hasChanges = true;
          }

          if (syncData.wallet != null &&
              (_wallet.depositBalance != syncData.wallet!.depositBalance ||
                  _wallet.winningBalance != syncData.wallet!.winningBalance ||
                  _wallet.bonusBalance != syncData.wallet!.bonusBalance)) {
            _wallet = syncData.wallet!;
            hasChanges = true;
          }

          if (syncData.transactions != null &&
              (syncData.transactions!.length != _transactions.length ||
                  (syncData.transactions!.isNotEmpty &&
                      _transactions.isNotEmpty &&
                      syncData.transactions!.first.id != _transactions.first.id))) {
            _transactions = syncData.transactions!;
            hasChanges = true;
          }

          if (syncData.withdrawals != null &&
              (syncData.withdrawals!.length != _withdrawals.length ||
                  (syncData.withdrawals!.isNotEmpty &&
                      _withdrawals.isNotEmpty &&
                      syncData.withdrawals!.first.status !=
                          _withdrawals.first.status))) {
            _withdrawals = syncData.withdrawals!;
            hasChanges = true;
          }

          if (syncData.notifications != null &&
              syncData.notifications!.length != _notifications.length) {
            _notifications = syncData.notifications!;
            hasChanges = true;
          }

          if (syncData.settings != null) {
            final newMinDep = syncData.settings!['minDeposit'] ?? 50;
            final newMinWth = syncData.settings!['minWithdrawal'] ?? 50;
            final newMaxDep = syncData.settings!['maxDeposit'] ?? 50000;
            final newMaxWth = syncData.settings!['maxWithdrawal'] ?? 100000;
            if (_minDeposit != newMinDep ||
                _minWithdrawal != newMinWth ||
                _maxDeposit != newMaxDep ||
                _maxWithdrawal != newMaxWth) {
              _minDeposit = newMinDep;
              _minWithdrawal = newMinWth;
              _maxDeposit = newMaxDep;
              _maxWithdrawal = newMaxWth;
              hasChanges = true;
            }
          }

          if (hasChanges) {
            _saveToStorage();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Sync with database error: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsLoggedInKey, _isLoggedIn);
      if (_isLoggedIn) {
        await prefs.setString(_prefUserKey, jsonEncode(_user.toJson()));
      }
      await prefs.setString(_prefWalletKey, jsonEncode(_wallet.toJson()));
      await prefs.setString(
          _prefArenasKey, jsonEncode(_arenas.map((a) => a.toJson()).toList()));
      await prefs.setString(_prefTransactionsKey,
          jsonEncode(_transactions.map((t) => t.toJson()).toList()));
      await prefs.setString(_prefWithdrawalsKey,
          jsonEncode(_withdrawals.map((w) => w.toJson()).toList()));
      await prefs.setString(_prefNotificationsKey,
          jsonEncode(_notifications.map((n) => n.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving storage: $e');
    }
  }

  void setWalletBalances({int? deposit, int? winning, int? bonus}) {
    _wallet = _wallet.copyWith(
      depositBalance: deposit,
      winningBalance: winning,
      bonusBalance: bonus,
    );
    _saveToStorage();
    notifyListeners();
  }

  void addTransaction(Transaction txn) {
    _transactions.insert(0, txn);
    _saveToStorage();
    notifyListeners();
  }

  void addNotification(String title, String message,
      [NotificationType type = NotificationType.info]) {
    final notif = NotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now().toIso8601String(),
      read: false,
    );
    _notifications.insert(0, notif);
    _saveToStorage();
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    _notifications = _notifications.map((n) {
      if (n.id == id) return n.copyWith(read: true);
      return n;
    }).toList();
    _saveToStorage();
    notifyListeners();
    ApiService.markNotificationRead(_user.id, id);
  }

  void markAllNotificationsAsRead() {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    _saveToStorage();
    notifyListeners();
    ApiService.markAllNotificationsRead(_user.id);
  }

  void updateProfile({
    String? fullName,
    String? username,
    String? email,
    String? phone,
  }) {
    _user = _user.copyWith(
      fullName: fullName,
      username: username,
      email: email,
      phone: phone,
    );
    addNotification(
      'Profile Updated',
      'Your profile information has been saved successfully.',
      NotificationType.success,
    );
    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.updateProfile(
      _user.id,
      fullName: fullName,
      username: username,
      email: email,
      phone: phone,
    );
  }

  void submitKyc(String docType, String docNumber) {
    _user = _user.copyWith(
      kycStatus: KycStatus.verified,
      kycDocumentType: docType,
      kycDocumentNumber: docNumber,
    );
    addNotification(
      'KYC Verified',
      'Your $docType ($docNumber) has been verified successfully.',
      NotificationType.success,
    );
    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.submitKyc(_user.id, docType, docNumber);
  }

  void saveGameId(String gameKey, String inGameId) {
    final newGameIds = Map<String, String>.from(_user.gameIds);
    newGameIds[gameKey] = inGameId;
    _user = _user.copyWith(gameIds: newGameIds);
    addNotification(
      'Game ID Saved',
      '$gameKey in-game ID set to "$inGameId".',
      NotificationType.success,
    );
    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.saveGameId(_user.id, gameKey, inGameId);
  }

  void savePayoutMethod(String type, dynamic data) {
    if (type == 'upi') {
      _user = _user.copyWith(upiId: data.toString());
      addNotification(
          'UPI Updated', 'Payout UPI set to $data', NotificationType.success);
    } else if (data is BankAccount) {
      _user = _user.copyWith(bankAccount: data);
      addNotification('Bank Account Updated',
          'Bank details saved for ${data.bankName}', NotificationType.success);
    }
    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.savePayoutMethod(_user.id, type, data);
  }

  Future<({
    bool success,
    String message,
    String? orderId,
    String? keyId,
    int? amount,
    int? amountInPaise,
    String? currency,
    Map<String, dynamic>? customer,
    bool isConfigured,
  })> createRazorpayOrder(int amount) async {
    if (amount <= 0) {
      return (
        success: false,
        message: 'Please enter a valid amount',
        orderId: null,
        keyId: null,
        amount: null,
        amountInPaise: null,
        currency: null,
        customer: null,
        isConfigured: false,
      );
    }
    if (amount < _minDeposit) {
      return (
        success: false,
        message: 'Minimum deposit amount is ₹$_minDeposit',
        orderId: null,
        keyId: null,
        amount: null,
        amountInPaise: null,
        currency: null,
        customer: null,
        isConfigured: false,
      );
    }
    if (amount > _maxDeposit) {
      return (
        success: false,
        message: 'Deposit limit is ₹$_maxDeposit',
        orderId: null,
        keyId: null,
        amount: null,
        amountInPaise: null,
        currency: null,
        customer: null,
        isConfigured: false,
      );
    }

    return await ApiService.createRazorpayOrder(
      userId: _user.id,
      amount: amount,
    );
  }

  Future<({bool success, String message, String? paymentId})> verifyRazorpayPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int amount,
  }) async {
    final res = await ApiService.verifyRazorpayPayment(
      userId: _user.id,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      amount: amount,
    );

    if (res.success && res.wallet != null) {
      _wallet = res.wallet!;

      final txn = Transaction(
        id: 'TXN_RZP_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        type: TransactionType.deposit,
        amount: amount,
        status: TransactionStatus.completed,
        title: 'Added Cash to Wallet',
        description: 'Payment via Razorpay ($paymentId)',
        timestamp: DateTime.now().toIso8601String(),
        referenceId: paymentId,
        paymentMethod: 'Razorpay',
      );

      _transactions.insert(0, txn);
      addNotification(
        'Razorpay Deposit Successful! 💳',
        '₹$amount has been added to your deposit balance via Razorpay.',
        NotificationType.success,
      );
      _saveToStorage();
      notifyListeners();
      return (success: true, message: res.message, paymentId: res.paymentId ?? paymentId);
    } else {
      return (success: false, message: res.message, paymentId: null);
    }
  }

  Future<({bool success, String message})> depositFunds(int amount, String method, [String? promoCode, String? utr]) async {
    if (amount <= 0) {
      return (success: false, message: 'Please enter a valid amount');
    }
    if (amount < _minDeposit) {
      return (success: false, message: 'Minimum deposit amount is ₹$_minDeposit');
    }
    if (amount > _maxDeposit) {
      return (success: false, message: 'Deposit limit is ₹$_maxDeposit');
    }

    // Call backend API for authoritative validation and balance update
    final serverRes = await ApiService.depositFunds(_user.id, amount, method, promoCode, utr);

    if (serverRes.success && serverRes.wallet != null) {
      _wallet = serverRes.wallet!;
      
      int bonus = 0;
      if (promoCode?.toUpperCase() == 'LUCKY100') {
        bonus = (amount * 0.2).round();
      } else if (promoCode?.toUpperCase() == 'FIRSTWIN') {
        bonus = 50;
      }

      final txn = Transaction(
        id: 'TXN_DEP_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        type: TransactionType.deposit,
        amount: amount,
        status: TransactionStatus.completed,
        title: 'Added Cash to Wallet',
        description: 'Payment via $method${bonus > 0 ? ' (+₹$bonus Bonus)' : ''}',
        timestamp: DateTime.now().toIso8601String(),
        referenceId: utr ?? 'REF${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: method,
      );

      _transactions.insert(0, txn);
      addNotification(
        'Deposit Successful',
        '₹$amount has been added to your deposit balance.${bonus > 0 ? ' Received ₹$bonus bonus cash!' : ''}',
        NotificationType.success,
      );
      _saveToStorage();
      notifyListeners();
      return (success: true, message: serverRes.message);
    } else {
      return (success: false, message: serverRes.message);
    }
  }

  ({bool success, String message}) withdrawFunds(
      int amount, PayoutMethod method, String details) {
    if (amount <= 0) {
      return (success: false, message: 'Please enter a valid amount');
    }
    if (amount < _minWithdrawal) {
      return (success: false, message: 'Minimum withdrawal amount is ₹$_minWithdrawal');
    }
    if (amount > _maxWithdrawal) {
      return (success: false, message: 'Maximum withdrawal limit is ₹$_maxWithdrawal');
    }
    if (amount > _wallet.winningBalance) {
      return (
        success: false,
        message:
            'Insufficient withdrawable winnings balance (Available: ₹${_wallet.winningBalance})'
      );
    }
    if (_user.kycStatus != KycStatus.verified) {
      return (
        success: false,
        message: 'KYC verification is required before initiating withdrawals.'
      );
    }

    _wallet = _wallet.copyWith(
      winningBalance: _wallet.winningBalance - amount,
    );

    final withdrawalId =
        'WTH_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final newWithdrawal = WithdrawalRequest(
      id: withdrawalId,
      amount: amount,
      method: method,
      accountDetails: details,
      status: 'requested',
      createdAt: DateTime.now().toIso8601String(),
      processedAt: null,
      txnReference: 'UTR${DateTime.now().millisecondsSinceEpoch}',
    );

    _withdrawals.insert(0, newWithdrawal);

    final newTxn = Transaction(
      id: 'TXN_$withdrawalId',
      type: TransactionType.withdrawal,
      amount: amount,
      status: TransactionStatus.pending,
      title: 'Withdrawal Request (4h Hold)',
      description: 'Requested via ${method.label} to $details. Security cooling period active.',
      timestamp: DateTime.now().toIso8601String(),
      referenceId: newWithdrawal.txnReference,
      paymentMethod: method.label,
    );

    _transactions.insert(0, newTxn);
    addNotification(
      'Withdrawal Requested 🕒',
      '₹$amount withdrawal request registered. Security verification hold active — processing begins in 4 hours.',
      NotificationType.info,
    );

    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.withdrawFunds(_user.id, amount, method.name, details);

    return (
      success: true,
      message: '₹$amount withdrawal requested. Status: REQUESTED (4h hold).'
    );
  }

  Arena createArena({
    required String title,
    required String game,
    required ArenaFormat format,
    required String map,
    required String server,
    required int entryFee,
    required int prizePool,
    int perKillPrize = 0,
    required int maxSlots,
    required String startTime,
    String? roomId,
    String? roomPassword,
    required List<String> rules,
  }) {
    final prize1 = (prizePool * 0.5).round();
    final prize2 = (prizePool * 0.3).round();
    final prize3 = (prizePool * 0.2).round();

    final newArena = Arena(
      id: 'arena_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      game: game,
      format: format,
      map: map.isNotEmpty ? map : 'Default Map',
      server: server.isNotEmpty ? server : 'Asia',
      entryFee: entryFee,
      prizePool: prizePool,
      perKillPrize: perKillPrize,
      maxSlots: maxSlots,
      registeredPlayers: [],
      startTime: startTime,
      status: ArenaStatus.upcoming,
      roomId: roomId?.isNotEmpty == true
          ? roomId
          : 'ROOM_${100000 + Random().nextInt(900000)}',
      roomPassword: roomPassword?.isNotEmpty == true
          ? roomPassword
          : 'PASS_${1000 + Random().nextInt(9000)}',
      rules: rules.isNotEmpty
          ? rules
          : [
              'Emulators/Cheats will lead to an immediate ban.',
              'Room ID & Password will be revealed 15 minutes before match start.',
              'Submit screenshot of final match results to claim winning prizes.',
              'Fair play guidelines must be respected by all participants.',
            ],
      prizeDistribution: [
        PrizeBreakdown(rank: '1st Place (Winner)', amount: prize1),
        PrizeBreakdown(rank: '2nd Place', amount: prize2),
        PrizeBreakdown(rank: '3rd Place', amount: prize3),
      ],
      createdBy: _user.id,
    );

    _arenas.insert(0, newArena);
    addNotification(
      'Arena Created',
      '"${newArena.title}" has been published and is open for registrations.',
      NotificationType.success,
    );
    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.createArena(
      userId: _user.id,
      title: title,
      game: game,
      format: format,
      map: map,
      server: server,
      entryFee: entryFee,
      prizePool: prizePool,
      perKillPrize: perKillPrize,
      maxSlots: maxSlots,
      startTime: startTime,
      roomId: roomId,
      roomPassword: roomPassword,
      rules: rules,
    );

    return newArena;
  }

  ({bool success, String message}) joinArena(
      String arenaId, String inGameId) {
    final index = _arenas.indexWhere((a) => a.id == arenaId);
    if (index == -1) {
      return (success: false, message: 'Arena not found.');
    }

    final arena = _arenas[index];
    if (arena.registeredPlayers.any((p) => p.userId == _user.id)) {
      return (
        success: false,
        message: 'You have already joined this arena.'
      );
    }

    if (arena.registeredPlayers.length >= arena.maxSlots) {
      return (success: false, message: 'Arena slots are already full.');
    }

    final totalAvailable = _wallet.depositBalance + _wallet.winningBalance;
    if (arena.entryFee > totalAvailable) {
      return (
        success: false,
        message:
            'Insufficient funds (Entry fee ₹${arena.entryFee}, Available: ₹$totalAvailable). Please deposit cash.'
      );
    }

    // Deduct entry fee
    int rem = arena.entryFee;
    int newDeposit = _wallet.depositBalance;
    int newWinning = _wallet.winningBalance;

    if (newDeposit >= rem) {
      newDeposit -= rem;
      rem = 0;
    } else {
      rem -= newDeposit;
      newDeposit = 0;
      newWinning -= rem;
    }

    _wallet = _wallet.copyWith(
      depositBalance: newDeposit,
      winningBalance: newWinning,
    );

    final finalInGameId = inGameId.isNotEmpty
        ? inGameId
        : (_user.gameIds[arena.game] ?? _user.username);

    final newPlayer = RegisteredPlayer(
      userId: _user.id,
      username: _user.username,
      inGameId: finalInGameId,
      joinedAt: DateTime.now().toIso8601String(),
    );

    final updatedArena = arena.copyWith(
      registeredPlayers: [...arena.registeredPlayers, newPlayer],
    );

    _arenas[index] = updatedArena;

    final newTxn = Transaction(
      id: 'TXN_JOIN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      type: TransactionType.entryFee,
      amount: arena.entryFee,
      status: TransactionStatus.completed,
      title: 'Joined: ${arena.title}',
      description: 'Entry fee for ${arena.game} (${arena.format.label})',
      timestamp: DateTime.now().toIso8601String(),
      referenceId: arena.id,
    );

    _transactions.insert(0, newTxn);
    addNotification(
      'Joined Arena!',
      'Successfully registered for "${arena.title}". Room details unlock before match starts.',
      NotificationType.success,
    );

    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.joinArena(arenaId, _user.id, finalInGameId);

    return (
      success: true,
      message: 'Successfully registered for "${arena.title}"!'
    );
  }

  ({bool success, String message}) leaveArena(String arenaId) {
    final index = _arenas.indexWhere((a) => a.id == arenaId);
    if (index == -1) {
      return (success: false, message: 'Arena not found.');
    }

    final arena = _arenas[index];
    final isJoined =
        arena.registeredPlayers.any((p) => p.userId == _user.id);
    if (!isJoined) {
      return (
        success: false,
        message: 'You are not registered in this arena.'
      );
    }

    final updatedPlayers =
        arena.registeredPlayers.where((p) => p.userId != _user.id).toList();

    _arenas[index] = arena.copyWith(
      registeredPlayers: updatedPlayers,
    );

    if (arena.entryFee > 0) {
      _wallet = _wallet.copyWith(
        depositBalance: _wallet.depositBalance + arena.entryFee,
      );

      final refundTxn = Transaction(
        id: 'TXN_REF_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        type: TransactionType.refund,
        amount: arena.entryFee,
        status: TransactionStatus.completed,
        title: 'Refund: ${arena.title}',
        description: 'Arena entry fee refunded to deposit balance',
        timestamp: DateTime.now().toIso8601String(),
        referenceId: arena.id,
      );

      _transactions.insert(0, refundTxn);
    }

    addNotification(
      'Registration Cancelled',
      'You left "${arena.title}". Entry fee has been refunded.',
      NotificationType.info,
    );

    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.leaveArena(arenaId, _user.id);

    return (
      success: true,
      message: 'Registration cancelled and refunded.'
    );
  }

  void claimPrizeWin(String arenaId, int amount) {
    final arena = _arenas.where((a) => a.id == arenaId).firstOrNull;

    _wallet = _wallet.copyWith(
      winningBalance: _wallet.winningBalance + amount,
    );

    final winTxn = Transaction(
      id: 'TXN_WIN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      type: TransactionType.prizeWon,
      amount: amount,
      status: TransactionStatus.completed,
      title: 'Prize Won: ${arena?.title ?? 'Arena Match'}',
      description: 'Match victory reward credited to Winnings balance',
      timestamp: DateTime.now().toIso8601String(),
      referenceId: arenaId,
    );

    _transactions.insert(0, winTxn);
    addNotification(
      'Victory! Prize Credited',
      'Congratulations! ₹$amount won from arena match has been credited to your withdrawable balance.',
      NotificationType.win,
    );

    _saveToStorage();
    notifyListeners();

    // Call backend API
    ApiService.claimPrizeWin(arenaId, _user.id, amount);
  }

  void updateWallet(Wallet newWallet) {
    _wallet = newWallet;
    _saveToStorage();
    notifyListeners();
  }

  Future<({bool success, String message})> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final res = await ApiService.changePassword(_user.id, currentPassword, newPassword);
    if (res.success) {
      addNotification(
        'Password Changed',
        'Your account password has been updated securely.',
        NotificationType.success,
      );
    }
    return res;
  }

  Future<void> resetToCleanState() async {
    try {
      await ApiService.resetAccount(_user.id);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _initDefaults();
    notifyListeners();
    await syncWithDatabase();
  }
}
