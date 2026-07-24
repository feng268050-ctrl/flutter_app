import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_coordinator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';
import 'package:lws_hmi/features/home/presentation/home_clock.dart';
import 'package:lws_hmi/features/home/presentation/home_quick_action.dart';
import 'package:lws_hmi/features/status_bar/live_product_status_items.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_mode_entry_tips_dialog.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_debug_log.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Design reference canvas from lws-ui `activity_main.xml` (1280×800).
const double _kDesignW = 1280;
const double _kDesignH = 800;

/// lws-ui `home_quick_action_*` dimens (design dp on 1280×800).
const double _kQaEdgeInset = 28;
const double _kQaPairGap = 28;
const double _kQaInner = 108;
const double _kQaIcon = 60;
const double _kQaWideInner = 244;
const double _kQaIconStartPad = 24;
const double _kQaIconTextGap = 8;
const double _kQaLabelMarginTop = 10;
const double _kQaCorner = 18;
const double _kQaCardText = 20;

/// Product Home: backdrop, animated plates, Quick/Engineer, bottom quick actions.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _homeBootstrapped = false;
  IpCameraUiStatus _cameraStatus = IpCameraUiStatus.connecting;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;

  Future<void> _openEngineerMode() async {
    final misc = MiscSettingsScope.maybeOf(context);
    if (misc?.hideEngineerModeEntryTip != true) {
      final result = await showEngineerModeEntryTipsDialog(context);
      if (result == null || !mounted) {
        return;
      }
      if (misc != null) {
        await misc.setHideEngineerModeEntryTip(result.dontShowAgain);
      }
    }
    if (mounted) {
      Navigator.of(context).pushNamed(AppRoutes.engineerMode);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapHome());
  }

  @override
  void dispose() {
    unawaited(_cameraSub?.cancel());
    super.dispose();
  }

  /// After first frame: IP camera session (async), optional once-per-boot
  /// self-check, then Modbus live.
  ///
  /// When startup self-check will show, continuous poll is suppressed until the
  /// dialog closes ([BootSelfCheckCoordinator.onComplete]). Otherwise Modbus
  /// starts immediately so alarms can subscribe without opening Monitor.
  void _bootstrapHome() {
    if (!mounted || _homeBootstrapped) {
      // #region agent log
      WarnAlarmDebugLog.log(
        hypothesisId: 'A',
        location: 'home_page.dart:_bootstrapHome',
        message: 'bootstrap skipped',
        data: {
          'mounted': mounted,
          'already': _homeBootstrapped,
        },
      );
      // #endregion
      return;
    }
    _homeBootstrapped = true;
    final services = AppScope.maybeOf(context);
    // #region agent log
    WarnAlarmDebugLog.log(
      hypothesisId: 'A',
      location: 'home_page.dart:_bootstrapHome',
      message: 'bootstrap begin',
      data: {
        'servicesNull': services == null,
        'shouldSkip': BootSelfCheckGate.shouldSkip,
        'gateActive': BootSelfCheckGate.isActive,
        'hasCompletedBoot': BootSelfCheckGate.hasCompletedThisBoot,
      },
    );
    // #endregion
    if (services == null) {
      return;
    }

    if (services.ipCameraSupported) {
      unawaited(_startIpCamera(services));
    }

    void startModbusLive() {
      if (!mounted) {
        return;
      }
      // #region agent log
      WarnAlarmDebugLog.log(
        hypothesisId: 'A',
        location: 'home_page.dart:startModbusLive',
        message: 'startModbusLive entered',
        data: {
          'warnScopeNull': WarnAlarmScope.maybeOf(context) == null,
          'gateActive': BootSelfCheckGate.isActive,
        },
      );
      // #endregion
      final warn = WarnAlarmScope.maybeOf(context);
      unawaited(() async {
        // Poll first so warn adapter prime sees cached attributes.
        await services.ensureModbusLive();
        // #region agent log
        WarnAlarmDebugLog.log(
          hypothesisId: 'E',
          location: 'home_page.dart:afterEnsureModbus',
          message: 'ensureModbusLive finished',
          data: {
            'modbusLiveStarted': services.modbusLiveStarted,
            'modbusLiveAllowed': services.modbusLiveAllowed,
            'warnNull': warn == null,
            'mounted': mounted,
          },
        );
        // #endregion
        if (!mounted || warn == null) {
          return;
        }
        // Let self-check route fully pop before warn dialogs use the navigator.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) {
          return;
        }
        await warn.start();
        // #region agent log
        WarnAlarmDebugLog.log(
          hypothesisId: 'A',
          location: 'home_page.dart:afterWarnStart',
          message: 'warn.start + flush done',
          data: const {},
        );
        // #endregion
        await warn.onPresentationGateOpened();
      }());
    }

    final settings = BootSelfCheckScope.maybeOf(context)?.settings;
    if (settings == null) {
      startModbusLive();
      return;
    }
    unawaited(
      BootSelfCheckCoordinator.startWhenHomeEntered(
        context: context,
        services: services,
        settings: settings,
        onComplete: startModbusLive,
      ),
    );
  }

  Future<void> _startIpCamera(AppServices services) async {
    try {
      final session = await services.ensureIpCamera();
      await session.start();
      if (!mounted) {
        return;
      }
      setState(() => _cameraStatus = session.currentStatus);
      await _cameraSub?.cancel();
      _cameraSub = session.status.listen((s) {
        if (mounted) {
          setState(() => _cameraStatus = s);
        }
      });
    } catch (e) {
      debugPrint('home: ip camera start failed: $e');
      if (mounted) {
        setState(() {
          _cameraStatus = const IpCameraUiStatus(
            phase: IpCameraUiPhase.failed,
            detail: 'start failed',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final processLibrary = ProcessLibraryScope.of(context);
    final hasSignedProcessLibrary =
        processLibrary.presets.any((preset) => preset.isBuiltin);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final sx = w / _kDesignW;
          final sy = h / _kDesignH;
          final qaScale = (sx + sy) / 2;
          final qaLabelSize = homeQuickActionLabelFontSize(_kQaInner * qaScale);
          // Wallpaper/GIF stack stays inside CyberBlurBackdropTarget (sibling capture).
          return CyberBlurBackdropScope(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CyberBlurBackdropTarget(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _HomeBackdrop(),
                      _HomeAnimatedPlate(
                        asset: HomeAssets.leftAnimated,
                        fallback: HomeAssets.leftStatic,
                        left: -60 * sx,
                        top: -90 * sy,
                        width: 600 * sx,
                        height: 600 * sy,
                      ),
                      _HomeAnimatedPlate(
                        asset: HomeAssets.rightAnimated,
                        fallback: HomeAssets.rightStatic,
                        left: 740 * sx,
                        top: -90 * sy,
                        width: 600 * sx,
                        height: 600 * sy,
                      ),
                      _PositionedAsset(
                        asset: HomeAssets.leftStatic,
                        left: 53 * sx,
                        top: 55 * sy,
                        width: 375 * sx,
                        height: 280 * sy,
                      ),
                      _PositionedAsset(
                        asset: HomeAssets.rightStatic,
                        left: 853 * sx,
                        top: 55 * sy,
                        width: 375 * sx,
                        height: 280 * sy,
                      ),
                    ],
                  ),
                ),
                // Top clock — slightly below vertical center of the design frame.
                Positioned(
                  left: 440 * sx,
                  top: 12 * sy,
                  width: 400 * sx,
                  height: 300 * sy,
                  child: Align(
                    alignment: const Alignment(0, 0.35),
                    child: HomeClock(
                      fontSize: 120 * sx,
                      sampleMode: CyberBlurSampleMode.realtime,
                    ),
                  ),
                ),
                // Top-right status strip (Wi‑Fi · BT · camera).
                Positioned(
                  right: 20 * sx,
                  top: 20 * sy,
                  child: HomeStatusBar(
                    cameraStatus: _cameraStatus,
                    iconSize: 32 * ((sx + sy) / 2),
                  ),
                ),
                _ModeEntry(
                  left: 53 * sx,
                  top: 55 * sy,
                  width: 375 * sx,
                  height: 280 * sy,
                  hero: HomeAssets.quickMode,
                  textLabel: l10n.homeQuickModeLabel,
                  heroSize: 280 * sx,
                  labelWidth: 348 * sx,
                  labelHeight: 130 * sy,
                  onTap: () {
                    if (!hasSignedProcessLibrary) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.noSignedProcessLibrary),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pushNamed(AppRoutes.quickMode);
                  },
                ),
                _ModeEntry(
                  left: 853 * sx,
                  top: 55 * sy,
                  width: 375 * sx,
                  height: 280 * sy,
                  hero: HomeAssets.engineerMode,
                  textLabel: l10n.homeEngineerModeLabel,
                  heroSize: 280 * sx,
                  labelWidth: 440 * sx,
                  labelHeight: 150 * sy,
                  onTap: () {
                    if (!hasSignedProcessLibrary) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.noSignedProcessLibrary),
                        ),
                      );
                      return;
                    }
                    unawaited(_openEngineerMode());
                  },
                ),
                // Bottom-left: Monitor | Settings (lws-ui box_quick_actions_row).
                Positioned(
                  left: _kQaEdgeInset * sx,
                  bottom: _kQaEdgeInset * sy,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _HomeQuickActionSquare(
                        scaleX: sx,
                        scaleY: sy,
                        iconAsset: HomeAssets.monitorIcon,
                        label: l10n.homeMonitorLabel,
                        labelFontSize: qaLabelSize,
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.monitor);
                        },
                      ),
                      SizedBox(width: _kQaPairGap * sx),
                      _HomeQuickActionSquare(
                        scaleX: sx,
                        scaleY: sy,
                        iconAsset: HomeAssets.settingsIcon,
                        label: l10n.homeSettingsLabel,
                        labelFontSize: qaLabelSize,
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.settings);
                        },
                      ),
                    ],
                  ),
                ),
                // Bottom-right: AI Vision wide card (lws-ui box_buttons_ai_vision).
                Positioned(
                  right: _kQaEdgeInset * sx,
                  bottom: _kQaEdgeInset * sy,
                  child: _HomeQuickActionAiVision(
                    scaleX: sx,
                    scaleY: sy,
                    labelFontSize: qaLabelSize,
                    l10n: l10n,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.aiVisionComingSoon),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);
    return Image.asset(
      HomeAssets.backdrop,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      cacheWidth: (size.width * dpr).round().clamp(640, 1920),
      cacheHeight: (size.height * dpr).round().clamp(400, 1200),
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
    );
  }
}

class _HomeAnimatedPlate extends StatelessWidget {
  const _HomeAnimatedPlate({
    required this.asset,
    required this.fallback,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String asset;
  final String fallback;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (width * dpr).round().clamp(200, 720);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        cacheWidth: cache,
        cacheHeight: cache,
        errorBuilder: (_, __, ___) => Image.asset(
          fallback,
          fit: BoxFit.contain,
          cacheWidth: cache,
          cacheHeight: cache,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PositionedAsset extends StatelessWidget {
  const _PositionedAsset({
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: (width * dpr).round().clamp(120, 800),
        cacheHeight: (height * dpr).round().clamp(120, 800),
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _ModeEntry extends StatelessWidget {
  const _ModeEntry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.hero,
    required this.textLabel,
    required this.heroSize,
    required this.labelWidth,
    required this.labelHeight,
    required this.onTap,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String hero;
  final String textLabel;
  final double heroSize;
  final double labelWidth;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            CyberClickSoundRegistry.playClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: ClipRect(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 12 * (height / 280).clamp(0.5, 2.0),
                  width: heroSize.clamp(48, width),
                  height: heroSize.clamp(48, height * 0.85),
                  child: Image.asset(
                    hero,
                    fit: BoxFit.contain,
                    cacheWidth: (heroSize * dpr).round().clamp(160, 640),
                    cacheHeight: (heroSize * dpr).round().clamp(160, 640),
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.touch_app,
                      size: heroSize * 0.35,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: labelHeight.clamp(24, height * 0.45),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        textLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (labelHeight * 0.28).clamp(18.0, 36.0),
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          shadows: const [
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickActionSquare extends StatelessWidget {
  const _HomeQuickActionSquare({
    required this.scaleX,
    required this.scaleY,
    required this.iconAsset,
    required this.label,
    required this.labelFontSize,
    required this.onPressed,
  });

  final double scaleX;
  final double scaleY;
  final String iconAsset;
  final String label;
  final double labelFontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = (scaleX + scaleY) / 2;
    final card = _kQaInner * s;
    final icon = _kQaIcon * s;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return HomeQuickAction(
      cardWidth: card,
      cardHeight: card,
      cornerRadius: _kQaCorner * s,
      labelMarginTop: _kQaLabelMarginTop * scaleY,
      labelFontSize: labelFontSize,
      sampleMode: CyberBlurSampleMode.realtime,
      label: label,
      onPressed: onPressed,
      child: Center(
        child: Image.asset(
          iconAsset,
          width: icon,
          height: icon,
          fit: BoxFit.contain,
          cacheWidth: (icon * dpr).round().clamp(48, 240),
          cacheHeight: (icon * dpr).round().clamp(48, 240),
          errorBuilder: (_, __, ___) => Icon(
            Icons.touch_app,
            color: Colors.white70,
            size: icon * 0.7,
          ),
        ),
      ),
    );
  }
}

class _HomeQuickActionAiVision extends StatelessWidget {
  const _HomeQuickActionAiVision({
    required this.scaleX,
    required this.scaleY,
    required this.labelFontSize,
    required this.l10n,
    required this.onPressed,
  });

  final double scaleX;
  final double scaleY;
  final double labelFontSize;
  final AppLocalizations l10n;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = (scaleX + scaleY) / 2;
    final width = _kQaWideInner * scaleX;
    final height = _kQaInner * s;
    final icon = _kQaIcon * s;
    final padStart = _kQaIconStartPad * scaleX;
    final gap = _kQaIconTextGap * scaleX;
    final textSize = (_kQaCardText * s).clamp(14.0, 22.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return HomeQuickAction(
      cardWidth: width,
      cardHeight: height,
      labelWidth: width,
      labelFontSize: labelFontSize,
      cornerRadius: _kQaCorner * s,
      labelMarginTop: _kQaLabelMarginTop * scaleY,
      sampleMode: CyberBlurSampleMode.realtime,
      label: l10n.homeAiVisionLabel,
      onPressed: onPressed,
      child: Row(
        children: [
          SizedBox(width: padStart),
          Image.asset(
            HomeAssets.aiVisionIcon,
            width: icon,
            height: icon,
            fit: BoxFit.contain,
            cacheWidth: (icon * dpr).round().clamp(48, 240),
            cacheHeight: (icon * dpr).round().clamp(48, 240),
            errorBuilder: (_, __, ___) => Icon(
              Icons.visibility,
              color: Colors.white70,
              size: icon * 0.7,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiDetectionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: textSize,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2 * scaleY),
                Text(
                  l10n.aiVisualizedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: textSize,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scaleX),
        ],
      ),
    );
  }
}
