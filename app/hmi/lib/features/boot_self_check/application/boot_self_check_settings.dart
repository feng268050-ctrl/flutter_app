import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';

/// Facade over [MiscSettingsStore] for boot self-check consumers / tests.
///
/// Production uses [miscStore]. Tests may pass [enabledOverrideForTest] to
/// force a value without touching disk.
final class BootSelfCheckSettings {
  BootSelfCheckSettings({
    MiscSettingsStore? miscStore,
    bool? enabledOverrideForTest,
  })  : _miscStore = miscStore,
        _enabledOverrideForTest = enabledOverrideForTest;

  final MiscSettingsStore? _miscStore;
  final bool? _enabledOverrideForTest;

  bool get isEnabled =>
      _enabledOverrideForTest ??
      _miscStore?.showStartupSelfCheck ??
      MiscSettingsStore.defaultShowStartupSelfCheck;

  /// Synchronous warm-read for bootstrap.
  bool warmRead() {
    final override = _enabledOverrideForTest;
    if (override != null) {
      return override;
    }
    final store = _miscStore;
    if (store != null) {
      store.warmRead();
      return store.showStartupSelfCheck;
    }
    return MiscSettingsStore.defaultShowStartupSelfCheck;
  }

  Future<bool> read() async {
    final override = _enabledOverrideForTest;
    if (override != null) {
      return override;
    }
    final store = _miscStore;
    if (store != null) {
      await store.read();
      return store.showStartupSelfCheck;
    }
    return MiscSettingsStore.defaultShowStartupSelfCheck;
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabledOverrideForTest != null) {
      return;
    }
    final store = _miscStore;
    if (store == null) {
      return;
    }
    await store.setShowStartupSelfCheck(enabled);
  }
}
