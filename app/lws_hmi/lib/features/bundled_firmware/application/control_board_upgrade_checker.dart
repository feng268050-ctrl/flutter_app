import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/infrastructure/bundled_firmware_assets.dart';

/// Offline control-board check: bundled asset filename HW match + SW newer.
///
/// Does not talk Modbus — caller supplies live [deviceHw]/[deviceSw].
class ControlBoardUpgradeChecker implements UpgradeChecker {
  ControlBoardUpgradeChecker({
    required this.deviceHw,
    required this.deviceSw,
    this.assetFileNames,
  });

  final int? deviceHw;
  final int? deviceSw;

  /// Discoverable `.bin` names; when null, loads from App assets.
  final List<String>? assetFileNames;

  @override
  Future<UpgradeCheckResult> check({
    required String currentVersion,
    UpgradePolicy policy = UpgradePolicy.operator,
  }) async {
    if (!shouldRunVersionCheck(policy)) {
      return const UpgradeCheckUnavailable(
        reason: 'version check skipped by policy',
      );
    }
    if (deviceHw == null || deviceSw == null) {
      return const UpgradeCheckUnavailable(reason: 'control versions missing');
    }

    final names =
        assetFileNames ?? await BundledFirmwareAssets.listFirmwareFileNames();
    final selected = BundledFirmwareAssets.selectLatestFileName(
      names,
      deviceHw: deviceHw,
    );
    if (selected == null) {
      return const UpgradeCheckUpToDate();
    }
    if (!BundledFirmwareVersionGate.isUpgradeCandidate(
      bundledFileName: selected,
      deviceHw: deviceHw,
      deviceSw: deviceSw,
    )) {
      return const UpgradeCheckUpToDate();
    }

    final bundledSw = BundledFirmwareVersionGate.softwareVersion(selected)!;
    return UpgradeCheckAvailable(
      UpgradeOffer(
        channel: UpgradeChannel.controlBoard,
        version: '$bundledSw',
        currentVersion: currentVersion,
        payload: selected,
      ),
    );
  }
}
