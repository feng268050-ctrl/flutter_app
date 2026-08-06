import 'package:cyber_upgrade_ui/src/domain/upgrade_offer.dart';

/// Outcome of a pluggable version check.
sealed class UpgradeCheckResult {
  const UpgradeCheckResult();
}

/// Running version is already current (or no newer offer).
class UpgradeCheckUpToDate extends UpgradeCheckResult {
  const UpgradeCheckUpToDate();
}

/// A newer package / firmware is available.
class UpgradeCheckAvailable extends UpgradeCheckResult {
  const UpgradeCheckAvailable(this.offer);

  final UpgradeOffer offer;
}

/// Check could not run (e.g. cloud off, no network, missing assets).
class UpgradeCheckUnavailable extends UpgradeCheckResult {
  const UpgradeCheckUnavailable({this.reason});

  final String? reason;
}

/// Check threw or returned an error.
class UpgradeCheckFailed extends UpgradeCheckResult {
  const UpgradeCheckFailed({this.error, this.message});

  final Object? error;
  final String? message;
}
