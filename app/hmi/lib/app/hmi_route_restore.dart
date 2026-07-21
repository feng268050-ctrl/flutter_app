import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_routes.dart';

/// Persist / consume a one-shot route restore after HMI restart (keyboard XKB).
abstract final class HmiRouteRestore {
  static const preferencePath = '/var/lib/hmi/hmi-restore-route';

  /// Deep-link token for Settings → Keyboard.
  static const settingsKeyboard = 'settings/keyboard';

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

  /// Map restore token → named [AppRoutes] (nested Keyboard push is App-owned).
  static String? namedRouteFor(String token) {
    if (token == settingsKeyboard || token.startsWith('settings')) {
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

  static bool wantsKeyboardPage(String? token) =>
      token == settingsKeyboard;
}
