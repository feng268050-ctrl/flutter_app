/// Operator / host policy for check + confirm gates.
class UpgradePolicy {
  const UpgradePolicy({
    this.checkVersion = true,
    this.requireConfirm = true,
  });

  /// When false, skip version-newer gates (host `make` push).
  final bool checkVersion;

  /// When false, skip operator confirm dialog (host `make` push).
  final bool requireConfirm;

  /// Typical host make-push: no version gate, no confirm.
  static const UpgradePolicy hostForce = UpgradePolicy(
    checkVersion: false,
    requireConfirm: false,
  );

  /// Typical operator Settings / Home flow.
  static const UpgradePolicy operator = UpgradePolicy();
}
