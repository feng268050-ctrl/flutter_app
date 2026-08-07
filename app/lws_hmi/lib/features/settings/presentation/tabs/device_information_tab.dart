import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/device/device_identity_qr.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/device/product_property_defaults.dart';
import 'package:lws_hmi/features/bundled_firmware/presentation/control_board_upgrade_page.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/settings/application/storage_capacity.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_storage_bar.dart';
import 'package:lws_hmi/features/system_ota/presentation/system_upgrade_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';
import 'package:lws_hmi/platform/cloud/secret_tap_tracker.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Device Information — CyberUI untitled cards (lws-ui Frost parity).
class DeviceInformationTab extends StatefulWidget {
  const DeviceInformationTab({
    super.key,
    required this.services,
    this.cameraDeviceInfoCache,
  });

  final AppServices services;

  /// Shared with Camera settings / cloud WS when provided by Settings.
  final CameraDeviceInfoCache? cameraDeviceInfoCache;

  @override
  State<DeviceInformationTab> createState() => _DeviceInformationTabState();
}

class _DeviceInformationTabState extends State<DeviceInformationTab> {
  String _deviceModel = kUnavailableDisplay;
  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _systemVersion = kUnavailableDisplay;
  String _controlCardVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;
  String _focusScaleRef = kUnavailableDisplay;
  String _cameraVersion = kUnavailableDisplay;
  StorageCapacitySummary _storage =
      const StorageCapacitySummary(
    segments: [],
    usedBytes: 0,
    availableBytes: 0,
    totalBytes: 0,
  );

  String? _brandRaw;
  String? _modelRaw;

  final SecretTapTracker _deviceSnSecretTap = SecretTapTracker();

  StreamSubscription<SysInfoUpdate>? _sysSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  late final CameraDeviceInfoCache _versionCache;
  late final bool _ownsVersionCache;

  @override
  void initState() {
    super.initState();
    final shared = widget.cameraDeviceInfoCache;
    _ownsVersionCache = shared == null;
    _versionCache = shared ?? CameraDeviceInfoCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  Future<void> _openSystemUpgrade() async {
    await pushSettingsPage(
      context,
      const SystemUpgradePage(),
    );
  }

  Future<void> _openControlBoardUpgrade() async {
    await pushSettingsPage(
      context,
      const ControlBoardUpgradePage(),
    );
  }

  Future<void> _start() async {
    try {
      _sysSub = widget.services.sysInfo
          .watch(interval: const Duration(seconds: 2))
          .listen(_onSys, onError: (_) {});
    } catch (_) {}

    unawaited(_refreshCameraVersion());

    try {
      await widget.services.ensureModbusLive();
      final stream = await widget.services.modbus.watchAttributes(
        ids: kDeviceInfoModbusWatchIds,
      );
      _modbusSub = stream.listen(_onModbus);
      try {
        final info = await widget.services.modbus.readGroup('info');
        _onModbus(modbusGroupToChanges(info));
      } catch (_) {}
    } catch (_) {}
  }

  static String _dash(String? value) {
    if (value == null || value.isEmpty) {
      return kUnavailableDisplay;
    }
    return value;
  }

  void _onSys(SysInfoUpdate update) {
    if (!mounted) return;
    final snap = update.snapshot;
    setState(() {
      _brandRaw = snap.brand;
      _modelRaw = snap.model;
      _deviceModel = productDeviceModelDisplay(snap.brand, snap.model);
      _deviceSn = _dash(snap.serialNumber);
      _systemVersion = snap.appVersion ?? kUnavailableDisplay;
      _storage = summarizeStorage(snap.storage);
    });
    unawaited(_refreshProductRows());
  }

  Future<void> _refreshProductRows() async {
    try {
      final product = await widget.services.ensureProductInfo();
      if (!mounted) return;
      setState(() {
        _focusScaleRef =
            _dash(effectiveFocusScaleRefFromProduct(product));
      });
    } catch (_) {}
  }

  Future<void> _refreshCameraVersion() async {
    try {
      final product = await widget.services.ensureProductInfo();
      final host = effectiveCameraHost(product);
      if (host.isEmpty) {
        if (mounted) {
          setState(() => _cameraVersion = kUnavailableDisplay);
        }
        return;
      }
      final version = await _versionCache.fetch(host);
      if (mounted) {
        setState(() => _cameraVersion = version);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraVersion = kUnavailableDisplay);
      }
    }
  }

  void _onModbus(List<ModbusAttributeChange> changes) {
    if (!mounted || changes.isEmpty) return;
    setState(() {
      for (final c in changes) {
        switch (c.id) {
          case 'device.control_card_version':
            _controlCardVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.laser_sw_version':
            _laserVersion =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
          case 'device.wire_feeder_sw_version':
            _wireFeederVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.gun_head_sn':
            _gunheadSn =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
        }
      }
    });
  }

  Future<void> _openDeviceQr() async {
    CyberClickSoundRegistry.playClick();
    final sn = _deviceSn == kUnavailableDisplay ? '' : _deviceSn;
    final model = productDeviceModelForQr(_brandRaw, _modelRaw);
    final version =
        _systemVersion == kUnavailableDisplay ? '' : _systemVersion;
    final payload = DeviceIdentityQr.contentV2(
      sn: sn,
      model: model,
      systemVersion: version,
    );
    if (!mounted) return;
    await showCyberDialog<void>(
      context: context,
      builder: (ctx) {
        return InkWell(
          onTap: () => Navigator.of(ctx).pop(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sysSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    if (_ownsVersionCache) {
      _versionCache.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsScrollView(
      children: [
        // Identity: Model + SN
        SettingsGroup(
          borderGradientCenter:
              CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            SettingsValueRow(
              title: l10n.deviceModel,
              value: _deviceModel,
              trailing: IconButton(
                tooltip: l10n.deviceModel,
                onPressed: () => unawaited(_openDeviceQr()),
                icon: const Icon(
                  Icons.qr_code_2,
                  color: CyberColors.textPrimary,
                ),
              ),
            ),
            SettingsValueRow(
              title: l10n.deviceSn,
              value: _deviceSn,
              clickFeedback: false,
              onTap: () {
                if (_deviceSnSecretTap.registerTap()) {
                  unawaited(_showSelectAppEnvDialog(l10n));
                }
              },
            ),
          ],
        ),
        // Versions: System, Camera, Control Board, Laser, Wire Feeder
        SettingsGroup(
          borderGradientCenter:
              CyberBorderGradientCenter.bottomLeftTopRight,
          children: [
            SettingsNavRow(
              title: l10n.systemVersion,
              value: _systemVersion,
              onTap: () => unawaited(_openSystemUpgrade()),
            ),
            SettingsValueRow(
              title: l10n.cameraVersion,
              value: _cameraVersion,
            ),
            SettingsNavRow(
              title: l10n.firmwareVersion,
              value: _controlCardVersion,
              onTap: () => unawaited(_openControlBoardUpgrade()),
            ),
            SettingsValueRow(
              title: l10n.laserVersion,
              value: _laserVersion,
            ),
            SettingsValueRow(
              title: l10n.wireFeederVersion,
              value: _wireFeederVersion,
            ),
          ],
        ),
        // Storage
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topBottom,
          children: [
            SettingsStorageBar(summary: _storage),
          ],
        ),
        // Accessory: Welding Gun SN + Focus Scale Reference
        SettingsGroup(
          borderGradientCenter:
              CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            SettingsValueRow(title: l10n.gunSn, value: _gunheadSn),
            SettingsValueRow(
              title: l10n.focusScaleReference,
              value: _focusScaleRef,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showSelectAppEnvDialog(AppLocalizations l10n) async {
    final store = CloudSettingsScope.maybeOf(context);
    if (store == null || !mounted) {
      return;
    }
    final current = store.environmentTier;
    String labelFor(CloudEnvironmentTier tier) => switch (tier) {
          CloudEnvironmentTier.dev => l10n.cloudEnvironmentTierDev,
          CloudEnvironmentTier.test => l10n.cloudEnvironmentTierTest,
          CloudEnvironmentTier.prod => l10n.cloudEnvironmentTierProd,
        };

    final chosen = await showCyberDialog<CloudEnvironmentTier>(
      context: context,
      builder: (ctx) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cloudEnvironmentTier,
                style: context.hmiTypography.settingsRowTitle.copyWith(
                  color: CyberColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final tier in CloudEnvironmentTier.values)
                ListTile(
                  title: Text(
                    labelFor(tier),
                    style: TextStyle(
                      color: tier == current
                          ? CyberColors.textPrimary
                          : CyberColors.textSecondary,
                    ),
                  ),
                  trailing: tier == current
                      ? const Icon(
                          Icons.check,
                          color: CyberColors.textPrimary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(tier),
                ),
              const SizedBox(height: 8),
              HmiButton(
                label: l10n.closeText,
                size: HmiButtonSize.small,
                shape: CyberButtonShape.rounded,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) {
      return;
    }
    await store.setEnvironmentTier(chosen);
    final runtime = CloudLocalRuntimeScope.maybeOf(context);
    unawaited(runtime?.reprobeAndReconnect());
  }
}
