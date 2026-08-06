import 'package:cyber_upgrade_ui/src/domain/upgrade_channel.dart';

/// Available update metadata for confirm / Update Now UI.
class UpgradeOffer {
  const UpgradeOffer({
    required this.channel,
    required this.version,
    this.currentVersion,
    this.notes,
    this.payload,
  });

  final UpgradeChannel channel;

  /// Newer / target version label (display string).
  final String version;

  /// Running / device version label when known.
  final String? currentVersion;

  /// Optional release notes / body copy.
  final String? notes;

  /// Opaque App payload (e.g. OTA manifest, asset path, bytes handle).
  final Object? payload;
}
