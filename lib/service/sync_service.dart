import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  bool _started = false;

  VoidCallback? onInternetAvailable;

  void start() {
    if (_started) return;

    _started = true;

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        debugPrint("🌐 Internet Connected");

        onInternetAvailable?.call();
      }
    });
  }
}