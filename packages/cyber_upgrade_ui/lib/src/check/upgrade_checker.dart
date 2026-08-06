import 'package:cyber_upgrade_ui/src/domain/upgrade_check_result.dart';
import 'package:cyber_upgrade_ui/src/domain/upgrade_policy.dart';

/// Pluggable version-check strategy (cloud HTTP, offline asset gate, …).
///
/// When [UpgradePolicy.checkVersion] is false, Apps MUST NOT use this checker
/// solely to block a host force apply.
abstract class UpgradeChecker {
  /// Compare [currentVersion] against the channel source of truth.
  Future<UpgradeCheckResult> check({
    required String currentVersion,
    UpgradePolicy policy = UpgradePolicy.operator,
  });
}

/// Helper: skip calling [checker] when policy disables version checks.
bool shouldRunVersionCheck(UpgradePolicy policy) => policy.checkVersion;
