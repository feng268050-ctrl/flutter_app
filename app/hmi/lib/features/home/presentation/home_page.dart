import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_coordinator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_scope.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';
import 'package:lws_hmi/features/home/presentation/home_clock.dart';
import 'package:lws_hmi/features/home/presentation/home_quick_action.dart';

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
  bool _selfCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartSelfCheck());
  }

  void _maybeStartSelfCheck() {
    if (!mounted || _selfCheckStarted) {
      return;
    }
    _selfCheckStarted = true;
    final settings = BootSelfCheckScope.maybeOf(context)?.settings;
    final services = AppScope.maybeOf(context);
    if (settings == null || services == null) {
      return;
    }
    unawaited(
      BootSelfCheckCoordinator.startWhenHomeEntered(
        context: context,
        services: services,
        settings: settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final sx = w / _kDesignW;
          final sy = h / _kDesignH;
          final qaScale = (sx + sy) / 2;
          final qaLabelSize =
              homeQuickActionLabelFontSize(_kQaInner * qaScale);
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
              _ModeEntry(
                left: 53 * sx,
                top: 55 * sy,
                width: 375 * sx,
                height: 280 * sy,
                hero: HomeAssets.quickMode,
                label: HomeAssets.quickModeTextEn,
                heroSize: 280 * sx,
                labelWidth: 348 * sx,
                labelHeight: 130 * sy,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quick Mode — coming soon')),
                  );
                },
              ),
              _ModeEntry(
                left: 853 * sx,
                top: 55 * sy,
                width: 375 * sx,
                height: 280 * sy,
                hero: HomeAssets.engineerMode,
                label: HomeAssets.engineerModeTextEn,
                heroSize: 280 * sx,
                labelWidth: 440 * sx,
                labelHeight: 150 * sy,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Engineer Mode — coming soon'),
                    ),
                  );
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
                      label: 'Monitor',
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
                      label: 'Settings',
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('AI Vision — coming soon'),
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
    required this.label,
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
  final String label;
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
                  child: Image.asset(
                    label,
                    fit: BoxFit.contain,
                    cacheWidth: (labelWidth * dpr).round().clamp(120, 800),
                    cacheHeight: (labelHeight * dpr).round().clamp(80, 400),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
    required this.onPressed,
  });

  final double scaleX;
  final double scaleY;
  final double labelFontSize;
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
      label: 'AI Vision',
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
                  'AI Detection',
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
                  'Visualized',
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
