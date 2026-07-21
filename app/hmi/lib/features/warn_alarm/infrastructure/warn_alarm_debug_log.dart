import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Session debug NDJSON for warn-alarm (board → pull to host).
abstract final class WarnAlarmDebugLog {
  static const path = '/var/lib/hmi/debug-warn-alarm.ndjson';
  static const sessionId = '438915';

  static void log({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, Object?> data = const {},
    String runId = 'pre',
  }) {
    final payload = <String, Object?>{
      'sessionId': sessionId,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'runId': runId,
      'data': data,
    };
    final line = jsonEncode(payload);
    // #region agent log
    try {
      File(path).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('warn-debug-log write failed: $e');
    }
    debugPrint('WARN_DBG $line');
    // #endregion
  }
}
