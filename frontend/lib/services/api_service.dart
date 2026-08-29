import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/arena.dart';
import '../models/user_profile.dart';
import '../models/wallet.dart';
import '../models/transaction.dart';
import '../models/withdrawal_request.dart';
import '../models/notification_item.dart';

class ApiService {
  static const String prodBackendUrl =
      'https://tournament-backend-idtb.onrender.com/api';

  static const String _configuredBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  // Base URL for API (supports Web on Render, custom URLs, Localhost, Mobile, Emulators)
  static String get baseUrl {
    if (_configuredBackendUrl.isNotEmpty) {
      return _configuredBackendUrl.endsWith('/api')
          ? _configuredBackendUrl
          : '$_configuredBackendUrl/api';
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://$host:5050/api';
      }
      return prodBackendUrl;
    }
    // Mobile / APK builds default to the live production server
    return prodBackendUrl;
  }

  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Check if the Node.js backend server is running and reachable
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate user via Login / Sign In
  static Future<({bool success, String message, UserProfile? user})> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Login successful',
          user: UserProfile.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Invalid credentials',
          user: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network connection failed', user: null);
    }
  }

  /// Register / Sign Up new user
  static Future<({bool success, String message, UserProfile? user})> register({
    required String username,
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Registration successful',
          user: UserProfile.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Registration failed',
          user: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', user: null);
    }
  }

  /// Forgot Password - Request OTP / Reset code
  static Future<({bool success, String message, String? demoOtp})> forgotPassword(
    String identifier,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: _headers,
        body: jsonEncode({'identifier': identifier}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        return (
          success: true,
          message: body['message'] as String? ?? 'Reset code sent',
          demoOtp: data != null ? data['resetOtp'] as String? : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Account not found',
          demoOtp: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', demoOtp: null);
    }
  }

  /// Reset Password with OTP & New Password
  static Future<({bool success, String message})> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: _headers,
        body: jsonEncode({
          'identifier': identifier,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Password reset successfully',
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to reset password',
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e');
    }
  }

  /// Sync full state for a given user from database
  static Future<({
    UserProfile? user,
    Wallet? wallet,
    List<Arena>? arenas,
    List<Transaction>? transactions,
    List<WithdrawalRequest>? withdrawals,
    List<NotificationItem>? notifications,
    Map<String, int>? settings,
  })?> fetchFullSync(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/sync/$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];

          final user = data['user'] != null
              ? UserProfile.fromJson(data['user'])
              : null;
          final wallet = data['wallet'] != null
              ? Wallet.fromJson(data['wallet'])
              : null;

          final arenaList = (data['arenas'] as List<dynamic>?)
                  ?.map((e) => Arena.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          final txnList = (data['transactions'] as List<dynamic>?)
                  ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          final wthList = (data['withdrawals'] as List<dynamic>?)
                  ?.map((e) =>
                      WithdrawalRequest.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          final notifList = (data['notifications'] as List<dynamic>?)
                  ?.map((e) =>
                      NotificationItem.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          Map<String, int>? settings;
          if (data['settings'] != null && data['settings'] is Map) {
            settings = {
              'minDeposit': (data['settings']['minDeposit'] as num?)?.toInt() ?? 50,
              'minWithdrawal': (data['settings']['minWithdrawal'] as num?)?.toInt() ?? 50,
              'maxDeposit': (data['settings']['maxDeposit'] as num?)?.toInt() ?? 50000,
              'maxWithdrawal': (data['settings']['maxWithdrawal'] as num?)?.toInt() ?? 100000,
            };
          }

          return (
            user: user,
            wallet: wallet,
            arenas: arenaList,
            transactions: txnList,
            withdrawals: wthList,
            notifications: notifList,
            settings: settings,
          );
        }
      }
    } catch (e) {
      debugPrint('ApiService.fetchFullSync error: $e');
    }
    return null;
  }

  /// Update user profile
  static Future<UserProfile?> updateProfile(
    String userId, {
    String? fullName,
    String? username,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/$userId'),
        headers: _headers,
        body: jsonEncode({
          if (fullName != null) 'fullName': fullName,
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return UserProfile.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.updateProfile error: $e');
    }
    return null;
  }

  /// Submit KYC
  static Future<UserProfile?> submitKyc(
    String userId,
    String docType,
    String docNumber,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/kyc'),
        headers: _headers,
        body: jsonEncode({'docType': docType, 'docNumber': docNumber}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return UserProfile.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.submitKyc error: $e');
    }
    return null;
  }

  /// Save In-Game ID
  static Future<UserProfile?> saveGameId(
    String userId,
    String gameKey,
    String inGameId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/game-id'),
        headers: _headers,
        body: jsonEncode({'gameKey': gameKey, 'inGameId': inGameId}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return UserProfile.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.saveGameId error: $e');
    }
    return null;
  }

  /// Save Payout Method
  static Future<UserProfile?> savePayoutMethod(
    String userId,
    String type,
    dynamic data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/payout'),
        headers: _headers,
        body: jsonEncode({
          'type': type,
          'data': data is BankAccount ? data.toJson() : data,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return UserProfile.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.savePayoutMethod error: $e');
    }
    return null;
  }

  /// Get Razorpay Public Configuration
  static Future<Map<String, dynamic>?> getRazorpayConfig() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/wallet/razorpay/config'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('ApiService.getRazorpayConfig error: $e');
    }
    return null;
  }

  /// Create Razorpay Order
  static Future<({
    bool success,
    String message,
    String? orderId,
    String? keyId,
    int? amount,
    int? amountInPaise,
    String? currency,
    Map<String, dynamic>? customer,
    bool isConfigured,
  })> createRazorpayOrder({
    required String userId,
    required int amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/$userId/razorpay/create-order'),
        headers: _headers,
        body: jsonEncode({
          'amount': amount,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true && body['data'] != null) {
        final d = body['data'];
        return (
          success: true,
          message: 'Razorpay order created',
          orderId: d['orderId'] as String?,
          keyId: d['keyId'] as String?,
          amount: (d['amount'] as num?)?.toInt(),
          amountInPaise: (d['amountInPaise'] as num?)?.toInt(),
          currency: d['currency'] as String? ?? 'INR',
          customer: d['customer'] as Map<String, dynamic>?,
          isConfigured: d['isConfigured'] == true,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to create Razorpay order',
          orderId: null,
          keyId: null,
          amount: null,
          amountInPaise: null,
          currency: null,
          customer: null,
          isConfigured: false,
        );
      }
    } catch (e) {
      debugPrint('ApiService.createRazorpayOrder error: $e');
      return (
        success: false,
        message: 'Connection error initiating Razorpay order: $e',
        orderId: null,
        keyId: null,
        amount: null,
        amountInPaise: null,
        currency: null,
        customer: null,
        isConfigured: false,
      );
    }
  }

  /// Verify Razorpay Payment Signature and Credit Wallet
  static Future<({bool success, String message, Wallet? wallet, String? paymentId})> verifyRazorpayPayment({
    required String userId,
    required String paymentId,
    required String orderId,
    required String signature,
    required int amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/$userId/razorpay/verify'),
        headers: _headers,
        body: jsonEncode({
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
          'amount': amount,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Razorpay payment verified',
          wallet: body['data'] != null ? Wallet.fromJson(body['data']) : null,
          paymentId: body['paymentId'] as String? ?? paymentId,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Razorpay verification failed',
          wallet: null,
          paymentId: null,
        );
      }
    } catch (e) {
      debugPrint('ApiService.verifyRazorpayPayment error: $e');
      return (
        success: false,
        message: 'Payment verification network error: $e',
        wallet: null,
        paymentId: null,
      );
    }
  }

  /// Deposit Funds (Legacy / Direct)
  static Future<({bool success, String message, Wallet? wallet})> depositFunds(
    String userId,
    int amount,
    String method, [
    String? promoCode,
    String? utr,
  ]) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/$userId/deposit'),
        headers: _headers,
        body: jsonEncode({
          'amount': amount,
          'method': method,
          if (promoCode != null) 'promoCode': promoCode,
          if (utr != null) 'utr': utr,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Deposit completed successfully',
          wallet: Wallet.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Deposit failed',
          wallet: null,
        );
      }
    } catch (e) {
      debugPrint('ApiService.depositFunds error: $e');
      return (
        success: false,
        message: 'Connection error: $e',
        wallet: null,
      );
    }
  }

  /// Withdraw Funds
  static Future<({bool success, String message, Wallet? wallet})> withdrawFunds(
    String userId,
    int amount,
    String method,
    String details,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/$userId/withdraw'),
        headers: _headers,
        body: jsonEncode({
          'amount': amount,
          'method': method,
          'details': details,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Withdrawal successful',
          wallet: Wallet.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Withdrawal failed',
          wallet: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', wallet: null);
    }
  }

  /// Create Arena Tournament
  static Future<Arena?> createArena({
    required String userId,
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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/arenas'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'game': game,
          'format': format.label,
          'map': map,
          'server': server,
          'entryFee': entryFee,
          'prizePool': prizePool,
          'perKillPrize': perKillPrize,
          'maxSlots': maxSlots,
          'startTime': startTime,
          'roomId': roomId,
          'roomPassword': roomPassword,
          'rules': rules,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return Arena.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.createArena error: $e');
    }
    return null;
  }

  /// Join Arena Tournament
  static Future<({bool success, String message, Arena? arena})> joinArena(
    String arenaId,
    String userId,
    String inGameId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/arenas/$arenaId/join'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'inGameId': inGameId}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Joined successfully',
          arena: Arena.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to join arena',
          arena: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', arena: null);
    }
  }

  /// Leave Arena Tournament
  static Future<({bool success, String message, Arena? arena})> leaveArena(
    String arenaId,
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/arenas/$arenaId/leave'),
        headers: _headers,
        body: jsonEncode({'userId': userId}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Left arena',
          arena: Arena.fromJson(body['data']),
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to leave arena',
          arena: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', arena: null);
    }
  }

  /// Claim Prize Win
  static Future<bool> claimPrizeWin(
    String arenaId,
    String userId,
    int amount,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/arenas/$arenaId/claim-win'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'amount': amount}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.claimPrizeWin error: $e');
      return false;
    }
  }

  /// Mark Notification Read
  static Future<void> markNotificationRead(String userId, String id) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/notifications/$userId/$id/read'),
        headers: _headers,
      );
    } catch (_) {}
  }

  /// Mark All Notifications Read
  static Future<void> markAllNotificationsRead(String userId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/notifications/$userId/read-all'),
        headers: _headers,
      );
    } catch (_) {}
  }

  /// Change User Password
  static Future<({bool success, String message})> changePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/change-password'),
        headers: _headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      final body = jsonDecode(response.body);
      return (
        success: response.statusCode == 200 && body['success'] == true,
        message: (body['message'] ?? body['error'] ?? 'Request completed') as String,
      );
    } catch (e) {
      return (success: false, message: 'Network error: $e');
    }
  }

  /// Reset Account to clean defaults
  static Future<({bool success, String message})> resetAccount(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/reset-account'),
        headers: _headers,
      );
      final body = jsonDecode(response.body);
      return (
        success: response.statusCode == 200 && body['success'] == true,
        message: (body['message'] ?? body['error'] ?? 'Reset complete') as String,
      );
    } catch (e) {
      return (success: false, message: 'Network error: $e');
    }
  }

  /// Fetch Live Aviator State from Server Game Engine
  static Future<Map<String, dynamic>?> getAviatorState([String? userId]) async {
    try {
      final uri = Uri.parse('$baseUrl/games/aviator/state${userId != null ? '?userId=$userId' : ''}');
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('getAviatorState error: $e');
    }
    return null;
  }

  /// Place Aviator Bet on Server
  static Future<({bool success, String message, Map<String, dynamic>? bet, Wallet? wallet})> placeAviatorBet({
    required String userId,
    int slotNum = 1,
    required int amount,
    bool autoCashoutEnabled = false,
    double autoCashoutValue = 2.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/aviator/bet'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'slotNum': slotNum,
          'amount': amount,
          'autoCashoutEnabled': autoCashoutEnabled,
          'autoCashoutValue': autoCashoutValue,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Bet placed successfully',
          bet: body['bet'] as Map<String, dynamic>?,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to place bet',
          bet: null,
          wallet: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', bet: null, wallet: null);
    }
  }

  /// Cancel Aviator Bet on Server
  static Future<({bool success, String message, Wallet? wallet})> cancelAviatorBet({
    required String userId,
    required String betId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/aviator/cancel-bet'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'betId': betId,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Bet cancelled',
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to cancel bet',
          wallet: null,
        );
      }
    } catch (e) {
      return (success: false, message: 'Network error: $e', wallet: null);
    }
  }

  /// Cashout Aviator Bet on Server
  static Future<({
    bool success,
    String message,
    int wonAmount,
    double cashoutMultiplier,
    Wallet? wallet,
  })> cashoutAviatorBet({
    required String userId,
    String? betId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/aviator/cashout'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          if (betId != null) 'betId': betId,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Cashed out successfully',
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          cashoutMultiplier: (body['cashoutMultiplier'] as num?)?.toDouble() ?? 1.0,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to cashout',
          wonAmount: 0,
          cashoutMultiplier: 1.0,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        wonAmount: 0,
        cashoutMultiplier: 1.0,
        wallet: null,
      );
    }
  }

  // ==================== MINES GOLD API ====================

  /// Start a Mines Game
  static Future<({
    bool success,
    String message,
    Map<String, dynamic>? round,
    Wallet? wallet,
    bool restored,
  })> startMines({
    required String userId,
    required int amount,
    int mineCount = 3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/mines/start'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'mineCount': mineCount,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Mines game started',
          round: body['round'] as Map<String, dynamic>?,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
          restored: body['restored'] == true,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to start game',
          round: null,
          wallet: null,
          restored: false,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        round: null,
        wallet: null,
        restored: false,
      );
    }
  }

  /// Reveal Tile in Mines
  static Future<({
    bool success,
    String message,
    String status,
    bool isMine,
    int tileIndex,
    double currentMultiplier,
    int wonAmount,
    double? nextMultiplier,
    List<int>? allMines,
    Map<String, dynamic>? round,
    Wallet? wallet,
  })> revealMinesTile({
    required String userId,
    required String roundId,
    required int tileIndex,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/mines/reveal'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'roundId': roundId,
          'tileIndex': tileIndex,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final rawMines = body['allMines'] as List<dynamic>?;
        final allMines = rawMines?.map((e) => (e as num).toInt()).toList();

        return (
          success: true,
          message: body['message'] as String? ?? (body['isMine'] == true ? 'Exploded!' : 'Diamond Found!'),
          status: body['status'] as String? ?? 'active',
          isMine: body['isMine'] == true,
          tileIndex: (body['tileIndex'] as num?)?.toInt() ?? tileIndex,
          currentMultiplier: (body['currentMultiplier'] as num?)?.toDouble() ?? 0.0,
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          nextMultiplier: (body['nextMultiplier'] as num?)?.toDouble(),
          allMines: allMines,
          round: body['round'] as Map<String, dynamic>?,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to reveal tile',
          status: 'error',
          isMine: false,
          tileIndex: tileIndex,
          currentMultiplier: 0.0,
          wonAmount: 0,
          nextMultiplier: null,
          allMines: null,
          round: null,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        status: 'error',
        isMine: false,
        tileIndex: tileIndex,
        currentMultiplier: 0.0,
        wonAmount: 0,
        nextMultiplier: null,
        allMines: null,
        round: null,
        wallet: null,
      );
    }
  }

  /// Cashout Mines
  static Future<({
    bool success,
    String message,
    double multiplier,
    int wonAmount,
    List<int>? allMines,
    Map<String, dynamic>? round,
    Wallet? wallet,
  })> cashoutMines({
    required String userId,
    required String roundId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/mines/cashout'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'roundId': roundId,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final rawMines = body['allMines'] as List<dynamic>?;
        final allMines = rawMines?.map((e) => (e as num).toInt()).toList();

        return (
          success: true,
          message: body['message'] as String? ?? 'Cashed out successfully',
          multiplier: (body['multiplier'] as num?)?.toDouble() ?? 1.0,
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          allMines: allMines,
          round: body['round'] as Map<String, dynamic>?,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to cashout',
          multiplier: 0.0,
          wonAmount: 0,
          allMines: null,
          round: null,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        multiplier: 0.0,
        wonAmount: 0,
        allMines: null,
        round: null,
        wallet: null,
      );
    }
  }

  /// Get Active Mines Round
  static Future<Map<String, dynamic>?> getMinesState(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/mines/state?userId=$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get Mines History
  static Future<List<dynamic>> getMinesHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/mines/history'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  // ==================== LUCKY WHEEL API ====================

  /// Get Wheel Segments
  static Future<List<dynamic>> getWheelSegments(String risk) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/wheel/segments?risk=$risk'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Spin Wheel
  static Future<({
    bool success,
    String message,
    int landingIndex,
    double multiplier,
    int wonAmount,
    bool isWin,
    Map<String, dynamic>? segment,
    Wallet? wallet,
  })> spinWheel({
    required String userId,
    required int amount,
    String risk = 'medium',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/wheel/spin'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'risk': risk,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Wheel spun successfully',
          landingIndex: (body['landingIndex'] as num?)?.toInt() ?? 0,
          multiplier: (body['multiplier'] as num?)?.toDouble() ?? 0.0,
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          isWin: body['isWin'] == true,
          segment: body['segment'] as Map<String, dynamic>?,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to spin wheel',
          landingIndex: 0,
          multiplier: 0.0,
          wonAmount: 0,
          isWin: false,
          segment: null,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        landingIndex: 0,
        multiplier: 0.0,
        wonAmount: 0,
        isWin: false,
        segment: null,
        wallet: null,
      );
    }
  }

  /// Get Wheel History
  static Future<List<dynamic>> getWheelHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/wheel/history'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  // ==================== CYBER DICE API ====================

  /// Roll Cyber Dice
  static Future<({
    bool success,
    String message,
    double rollResult,
    int dice1,
    int dice2,
    int sum,
    bool isWin,
    double multiplier,
    int wonAmount,
    double winChance,
    Wallet? wallet,
  })> rollDice({
    required String userId,
    required int amount,
    String mode = 'slider',
    double target = 50.0,
    String condition = 'under',
    String choice = 'low',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/dice/roll'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'mode': mode,
          'target': target,
          'condition': condition,
          'choice': choice,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return (
          success: true,
          message: body['message'] as String? ?? 'Dice rolled successfully',
          rollResult: (body['rollResult'] as num?)?.toDouble() ?? 0.0,
          dice1: (body['dice1'] as num?)?.toInt() ?? 1,
          dice2: (body['dice2'] as num?)?.toInt() ?? 1,
          sum: (body['sum'] as num?)?.toInt() ?? 2,
          isWin: body['isWin'] == true,
          multiplier: (body['multiplier'] as num?)?.toDouble() ?? 0.0,
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          winChance: (body['winChance'] as num?)?.toDouble() ?? 0.0,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to roll dice',
          rollResult: 0.0,
          dice1: 1,
          dice2: 1,
          sum: 2,
          isWin: false,
          multiplier: 0.0,
          wonAmount: 0,
          winChance: 0.0,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        rollResult: 0.0,
        dice1: 1,
        dice2: 1,
        sum: 2,
        isWin: false,
        multiplier: 0.0,
        wonAmount: 0,
        winChance: 0.0,
        wallet: null,
      );
    }
  }

  /// Get Dice History
  static Future<List<dynamic>> getDiceHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/dice/history'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }

  // ==================== PLINKO API ====================

  /// Get Plinko Multipliers for given rows & risk
  static Future<List<double>> getPlinkoMultipliers({int rows = 8, String risk = 'medium'}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/plinko/multipliers?rows=$rows&risk=$risk'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return (body['data'] as List).map((e) => (e as num).toDouble()).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Drop Plinko Ball
  static Future<({
    bool success,
    String message,
    String? roundId,
    int rows,
    String risk,
    List<int> path,
    int landingIndex,
    double multiplier,
    int wonAmount,
    bool isWin,
    Wallet? wallet,
  })> dropPlinkoBall({
    required String userId,
    required int amount,
    int rows = 8,
    String risk = 'medium',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/plinko/drop'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'rows': rows,
          'risk': risk,
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final rawPath = body['path'] as List<dynamic>?;
        final path = rawPath?.map((e) => (e as num).toInt()).toList() ?? [];

        return (
          success: true,
          message: body['message'] as String? ?? 'Ball dropped',
          roundId: body['roundId'] as String?,
          rows: (body['rows'] as num?)?.toInt() ?? rows,
          risk: body['risk'] as String? ?? risk,
          path: path,
          landingIndex: (body['landingIndex'] as num?)?.toInt() ?? 0,
          multiplier: (body['multiplier'] as num?)?.toDouble() ?? 0.0,
          wonAmount: (body['wonAmount'] as num?)?.toInt() ?? 0,
          isWin: body['isWin'] == true,
          wallet: body['wallet'] != null ? Wallet.fromJson(body['wallet']) : null,
        );
      } else {
        return (
          success: false,
          message: body['error'] as String? ?? 'Failed to drop ball',
          roundId: null,
          rows: rows,
          risk: risk,
          path: <int>[],
          landingIndex: 0,
          multiplier: 0.0,
          wonAmount: 0,
          isWin: false,
          wallet: null,
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        roundId: null,
        rows: rows,
        risk: risk,
        path: <int>[],
        landingIndex: 0,
        multiplier: 0.0,
        wonAmount: 0,
        isWin: false,
        wallet: null,
      );
    }
  }

  /// Get Plinko Drop History
  static Future<List<dynamic>> getPlinkoHistory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/games/plinko/history'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (_) {}
    return [];
  }
}

