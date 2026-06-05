import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// A singleton service that monitors network connectivity changes.
/// It exposes:
///  - [isOnline]: current connectivity state
///  - [onReconnected]: stream that fires when network is restored
///
/// Register callbacks with [addReconnectCallback] to be called when
/// the network comes back online (e.g. re-fetch data).
class NetworkMonitor extends ChangeNotifier {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  bool _isOnline = true;
  bool _wasOffline = false;

  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _reconnectController = StreamController<void>.broadcast();

  /// Stream that emits when network connectivity is restored after being lost.
  Stream<void> get onReconnected => _reconnectController.stream;

  /// List of callbacks to invoke on reconnection.
  final List<VoidCallback> _reconnectCallbacks = [];

  void addReconnectCallback(VoidCallback callback) {
    _reconnectCallbacks.add(callback);
  }

  void removeReconnectCallback(VoidCallback callback) {
    _reconnectCallbacks.remove(callback);
  }

  Future<void> init() async {
    // Get initial connectivity status
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = !(results.isEmpty || results.contains(ConnectivityResult.none));
      _wasOffline = !_isOnline;
    } catch (_) {}

    _subscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final nowOnline =
            !(results.isEmpty || results.contains(ConnectivityResult.none));

        if (!nowOnline && _isOnline) {
          // Just went offline
          _isOnline = false;
          _wasOffline = true;
          notifyListeners();
          debugPrint('📡 NetworkMonitor: Connection lost');
        } else if (nowOnline && !_isOnline) {
          // Just came back online
          _isOnline = true;
          notifyListeners();
          debugPrint('📡 NetworkMonitor: Connection restored');

          if (_wasOffline) {
            _wasOffline = false;
            // Notify all registered callbacks to reload
            _reconnectController.add(null);
            for (final cb in List<VoidCallback>.from(_reconnectCallbacks)) {
              try {
                cb();
              } catch (e) {
                debugPrint('📡 NetworkMonitor: Reconnect callback error: $e');
              }
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectController.close();
    super.dispose();
  }
}
