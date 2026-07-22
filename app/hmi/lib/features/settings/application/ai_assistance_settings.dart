import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';

/// Read/write facade for AI assistance toggles (App store, not Modbus).
///
/// Non-UI consumers (StreamDetect / stain / zero-point coordinators when
/// present) MUST read via this facade, not InheritedWidget UI state.
///
/// TODO(ai): Wire [lensContaminationDetectionEnabled] /
/// [zeroPointOffsetDetectionEnabled] into StreamDetect / OpencvStain /
/// ZeroPoint coordinators when those modules land. Manual Zero Offset Auto
/// remains ungated.
final class AiAssistanceSettings extends ChangeNotifier {
  AiAssistanceSettings(this._store) {
    _store.addListener(_onStoreChanged);
  }

  final AdvancedSettingsStore _store;

  bool get lensContaminationDetectionEnabled =>
      _store.lensContaminationDetectionEnabled;

  bool get zeroPointOffsetDetectionEnabled =>
      _store.zeroPointOffsetDetectionEnabled;

  Future<void> setLensContaminationDetectionEnabled(bool enabled) =>
      _store.setLensContaminationDetectionEnabled(enabled);

  Future<void> setZeroPointOffsetDetectionEnabled(bool enabled) =>
      _store.setZeroPointOffsetDetectionEnabled(enabled);

  void _onStoreChanged() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
