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
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/system_ota/presentation/system_ota_settings_page.dart';
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
  const DeviceInformationTab({super.key, required this.services});

  final AppServices services;

  @override
  State<DeviceInformationTab> createState() => _DeviceInformationTabState();
}

class _DeviceInformationTabState extends State<DeviceInformationTab> {
  String _deviceModel = kUnavailableDisplay;
  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _systemVersion = kUnavailableDisplay;
  String _kernelVersion = kUnavailableDisplay;
  String _controlCardVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;
  String _focusScaleRef = kUnavailableDisplay;
  String _processLibVersion = kUnavailableDisplay;

  String? _brandRaw;
  String? _modelRaw;

  final SecretTapTracker _deviceSnSecretTap = SecretTapTracker();

  StreamSubscription<SysInfoUpdate>? _sysSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
      _refreshProcessLib();
    });
  }

  Future<void> _start() async {
    try {
      _sysSub = widget.services.sysInfo
          .watch(interval: const Duration(seconds: 2))
          .listen(_onSys, onError: (_) {});
    } catch (_) {}

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
      _kernelVersion = snap.kernelRelease ?? kUnavailableDisplay;
      _systemVersion = snap.appVersion ?? kUnavailableDisplay;
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

  void _refreshProcessLib() {
    try {
      final lib = ProcessLibraryScope.of(context);
      final fromPreset = lib.presets
          .map((p) => p.libraryVersion)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
      if (!mounted) return;
      setState(() {
        _processLibVersion = _dash(fromPreset);
      });
    } catch (_) {}
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Refresh process-lib label when scope notifies.
    try {
      final lib = ProcessLibraryScope.of(context);
      final v = lib.presets
          .map((p) => p.libraryVersion)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
      final next = _dash(v);
      if (next != _processLibVersion) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _processLibVersion = next);
        });
      }
    } catch (_) {}

    return SettingsScrollView(
      children: [
        // Identity — lws-ui `top-left-bottom-right`
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
            SettingsValueRow(title: l10n.gunSn, value: _gunheadSn),
          ],
        ),
        // Versions — lws-ui `bottom-left-top-right`
        SettingsGroup(
          borderGradientCenter:
              CyberBorderGradientCenter.bottomLeftTopRight,
          children: [
            SettingsValueRow(
              title: l10n.systemVersion,
              value: _systemVersion,
            ),
            SettingsValueRow(
              title: l10n.kernelVersion,
              value: _kernelVersion,
            ),
            SettingsValueRow(
              title: l10n.processLibVersion,
              value: _processLibVersion,
            ),
            SettingsValueRow(
              title: l10n.firmwareVersion,
              value: _controlCardVersion,
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
        // Focus — lws-ui `top-bottom`
        SettingsGroup(
          borderGradientCenter: CyberBorderGradientCenter.topBottom,
          children: [
            SettingsValueRow(
              title: l10n.focusScaleReference,
              value: _focusScaleRef,
            ),
          ],
        ),
        // System upgrade → dedicated Settings OTA sub-page
        SettingsGroup(
          borderGradientCenter:
              CyberBorderGradientCenter.topLeftBottomRight,
          children: [
            SettingsNavRow(
              title: l10n.systemUpgradeTitle,
              value: _systemVersion,
              onTap: () {
                unawaited(
                  pushSettingsPage(
                    context,
                    const SystemOtaSettingsPage(),
                  ),
                );
              },
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
        // ListTiles stretch to max width; cap like other compact Cyber dialogs.
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
