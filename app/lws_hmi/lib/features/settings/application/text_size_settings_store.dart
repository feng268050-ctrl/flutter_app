import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/app_text_size.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// App-owned reading text-size preference in common-settings.json.
///
/// Locale preferences live in HAL's locale.conf; this store deliberately owns
/// only the App-specific `textSize` key.
final class TextSizeSettingsStore extends ChangeNotifier {
  TextSizeSettingsStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/common-settings.json';

  static const keyTextSize = 'textSize';
  static const defaultTextSize = AppTextSize.defaultSize;
  static const supportedTextSizes = AppTextSize.supported;

  final String preferencePath;
  AppTextSize _textSize = defaultTextSize;
  bool _warmed = false;

  AppTextSize get textSize => _textSize;

  void warmRead() {
    if (_warmed) return;
    try {
      final file = File(preferencePath);
      if (file.existsSync()) _applyJson(file.readAsStringSync());
    } catch (_) {
      _textSize = defaultTextSize;
    }
    _warmed = true;
  }

  Future<void> setTextSize(AppTextSize value) async {
    warmRead();
    if (_textSize == value) return;
    _textSize = value;
    try {
      final file = File(preferencePath);
      Map<String, dynamic> values = <String, dynamic>{};
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) values = Map<String, dynamic>.from(decoded);
      }
      values[keyTextSize] = value.wire;
      await file.parent.create(recursive: true);
      await file.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(values)}\n');
    } catch (_) {
      // Keep the in-memory preference usable if persistent storage is absent.
    }
    notifyListeners();
  }

  void _applyJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded[keyTextSize] != null) {
        _textSize = AppTextSize.parse('${decoded[keyTextSize]}');
      }
    } catch (_) {
      _textSize = defaultTextSize;
    }
  }
}
