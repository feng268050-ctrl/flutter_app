import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';
import 'package:lws_hmi/features/home/presentation/home_temperature_card.dart';

/// Design reference canvas from lws-ui `activity_main.xml` (1280×800).
const double _kDesignW = 1280;
const double _kDesignH = 800;

/// Product Home: backdrop, animated plates, Quick/Engineer heroes, Settings.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final sx = w / _kDesignW;
          final sy = h / _kDesignH;
          return Stack(
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
              Positioned(
                left: 72 * sx,
                right: 72 * sx,
                top: 360 * sy,
                child: const HomeTemperatureCard(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40 * sy,
                child: Center(
                  child: _SettingsEntry(
                    iconAsset: HomeAssets.settingsIcon,
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.settings);
                    },
                  ),
                ),
              ),
            ],
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
          onTap: onTap,
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

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({required this.onPressed, this.iconAsset});

  final VoidCallback onPressed;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconAsset != null)
                Image.asset(
                  iconAsset!,
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 28,
                  ),
                )
              else
                const Icon(Icons.settings, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
