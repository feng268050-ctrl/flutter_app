import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_routes.dart';

/// Persist / consume a one-shot route restore after HMI restart.
///
/// Keyboard XKB restart used to write `settings/keyboard` and reopen
/// Settings → Keyboard. That page migrated to the OS Settings seat, so the
/// nested deep-link was removed. Stale `settings/*` tokens still open
/// [AppRoutes.settings] (Device Info tab) without pushing a nested page —
/// soft no-op for the old keyboard path. Prefer not writing new tokens for
/// migrated features.
abstract final class HmiRouteRestore {
  static const preferencePath = '/var/lib/hmi/hmi-restore-route';

  static Future<void> write(String token) async {
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(token, flush: true);
    } catch (e) {
      debugPrint('hmi-restore-route write failed: $e');
    }
  }

  /// Returns the token and deletes the file (consume-once).
  static Future<String?> take() async {
    try {
      final f = File(preferencePath);
      if (!await f.exists()) return null;
      final token = (await f.readAsString()).trim();
      await f.delete();
      if (token.isEmpty) return null;
      return token;
    } catch (e) {
      debugPrint('hmi-restore-route take failed: $e');
      return null;
    }
  }

  /// Map restore token → named [AppRoutes].
  static String? namedRouteFor(String token) {
    if (token.startsWith('settings')) {
      return AppRoutes.settings;
    }
    if (token == AppRoutes.monitor || token == 'monitor') {
      return AppRoutes.monitor;
    }
    if (token == AppRoutes.demo || token == 'demo') {
      return AppRoutes.demo;
    }
    if (token == AppRoutes.home || token == 'home' || token == '/') {
      return AppRoutes.home;
    }
    return null;
  }
}
