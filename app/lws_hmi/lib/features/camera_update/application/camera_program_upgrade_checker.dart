import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';

/// Stub checker for [UpgradeChannel.cameraProgram].
///
/// Camera flash protocol is **out of scope** for the cyber_upgrade_ui package —
/// product Apps plug a real offline/HTTP checker and transfer path later.
/// This stub always reports unavailable so no operator UI is required yet.
class CameraProgramUpgradeChecker implements UpgradeChecker {
  const CameraProgramUpgradeChecker();

  static const UpgradeChannel channel = UpgradeChannel.cameraProgram;

  @override
  Future<UpgradeCheckResult> check({
    required String currentVersion,
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!shouldRunVersionCheck(policy)) {
      return const UpgradeCheckUnavailable(
        reason: 'camera program version check skipped by policy',
      );
    }
    return const UpgradeCheckUnavailable(
      reason: 'camera program upgrade not implemented',
    );
  }
}
