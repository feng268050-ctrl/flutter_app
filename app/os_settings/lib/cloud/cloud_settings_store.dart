import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:cyber_hal/network/cloud_origin.dart';
import 'package:flutter/foundation.dart';

export 'package:cyber_hal/network/cloud_environment.dart'
    show
        CloudEnvironmentTier,
        CloudEnvironmentTierCodec,
        kCloudEnvironmentTiers;

/// Shared cloud API env tier (`/var/lib/network/cloud.conf`).
///
/// Product HMI opt-in toggles stay in `/var/lib/hmi/cloud-settings.json`.
final class CloudSettingsStore extends ChangeNotifier {
  CloudSettingsStore({
    String? preferencePath,
    String? legacyJsonPath,
  })  : preferencePath = preferencePath ?? CloudEnvironmentPrefs.confPath,
        legacyJsonPath =
            legacyJsonPath ?? CloudEnvironmentPrefs.legacyJsonPath;

  static const defaultEnvironmentTier = CloudEnvironmentTier.prod;

  final String preferencePath;
  final String legacyJsonPath;

  CloudEnvironmentTier _environmentTier = defaultEnvironmentTier;
  bool _warmed = false;

  CloudEnvironmentTier get environmentTier => _environmentTier;

  void warmRead() {
    if (_warmed) {
      return;
    }
    try {
      _environmentTier = CloudEnvironmentPrefs.readOrMigrateSync(
        conf: preferencePath,
        legacyJson: legacyJsonPath,
      );
    } catch (e) {
      debugPrint('cloud-settings: warmRead failed: $e');
      _environmentTier = defaultEnvironmentTier;
    }
    _warmed = true;
  }

  Future<void> setEnvironmentTier(CloudEnvironmentTier tier) async {
    warmRead();
    if (_environmentTier == tier) {
      return;
    }
    _environmentTier = tier;
    await CloudEnvironmentPrefs.write(tier, preferencePath);
    // Drop boot-scoped origin pin so next App probe uses the new tier.
    CloudApiOriginProber(pinPath: CloudApiOriginProber.defaultPinPath).clearPin();
    notifyListeners();
  }
}
