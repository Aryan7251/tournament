import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _statusController.stream;

  bool _isChecking = false;
  Timer? _heartbeatTimer;

  void initialize() {
    _subscription?.cancel();
    
    // Initial check
    checkInternetConnection();

    // Listen to network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityResults(results);
    });

    // Periodic heartbeat verification every 15 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkInternetConnection(silent: true);
    });
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    final bool hasInterface = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);

    if (!hasInterface) {
      _updateStatus(false);
    } else {
      // Interface is up, verify actual internet reachability
      checkInternetConnection();
    }
  }

  /// Probes real internet reachability
  Future<bool> checkInternetConnection({bool silent = false}) async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    bool online = false;

    try {
      // First check interface
      final results = await _connectivity.checkConnectivity();
      final hasInterface = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (!hasInterface) {
        online = false;
      } else {
        // Probe reachable public DNS / endpoint with short timeout
        final probeUrls = [
          Uri.parse('https://dns.google/resolve?name=example.com'),
          Uri.parse('https://cloudflare-dns.com/dns-query?name=example.com'),
          Uri.parse('https://www.google.com/generate_204'),
        ];

        for (final url in probeUrls) {
          try {
            final response = await http
                .get(url, headers: {'Accept': 'application/dns-json'})
                .timeout(const Duration(seconds: 4));
            if (response.statusCode >= 200 && response.statusCode < 400) {
              online = true;
              break;
            }
          } catch (_) {
            // Try next probe
          }
        }
      }
    } catch (_) {
      online = false;
    } finally {
      _isChecking = false;
      _updateStatus(online);
    }

    return online;
  }

  void _updateStatus(bool newStatus) {
    if (isOnlineNotifier.value != newStatus) {
      isOnlineNotifier.value = newStatus;
      _statusController.add(newStatus);
      if (kDebugMode) {
        print('🌐 [ConnectivityService] Network status changed: ${newStatus ? "ONLINE" : "OFFLINE"}');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    _statusController.close();
  }
}
