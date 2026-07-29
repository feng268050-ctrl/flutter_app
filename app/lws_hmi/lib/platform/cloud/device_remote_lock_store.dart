import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Persisted remote lock flag (`/var/lib/hmi/remote-lock.json`).
final class DeviceRemoteLockStore extends ChangeNotifier {
  DeviceRemoteLockStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/remote-lock.json';

  final String preferencePath;
  bool _locked = false;
  bool _warmed = false;

  bool get isLocked => _locked;

  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        final decoded = jsonDecode(f.readAsStringSync());
        if (decoded is Map && decoded['locked'] is bool) {
          _locked = decoded['locked'] as bool;
        }
      }
    } catch (e) {
      debugPrint('remote-lock: warmRead failed: $e');
      _locked = false;
    }
    _warmed = true;
  }

  Future<void> setLocked(bool locked) async {
    warmRead();
    if (_locked == locked) {
      return;
    }
    _locked = locked;
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'locked': locked})}\n',
      );
    } catch (e) {
      debugPrint('remote-lock: write failed: $e');
    }
    notifyListeners();
  }
}
