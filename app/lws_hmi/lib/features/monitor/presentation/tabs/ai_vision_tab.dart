import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `fragment_ai_vision` — info panel + choose button + preview overlays.
class AiVisionTab extends StatelessWidget {
  const AiVisionTab({super.key});

  /// lws-ui label bar fill `#CC2E3653`.
  static const _labelBar = Color(0xCC2E3653);

  /// Demo HUD status token for the top-right chip (logic later).
  static const _demoHudStatus = 'CLEAN';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MonitorDimens.aiInfoW,
            child: Column(
              children: [
                Expanded(
                  child: MonitorGlassCard(
                    padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 21),
                          child: Text(
                            l10n.deviceMonitorWorkInfoTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 35,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionProcessTypeText,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionMaterialTypeText,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                        _InfoBlock(
                          label: l10n.processVideoRecordingTime,
                          value: l10n.aiVisionWorkInfoUnavailable,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CyberButton(
                    size: CyberButtonSize.medium,
                    variant: CyberButtonVariant.primary,
                    shape: CyberButtonShape.rounded,
                    stretch: true,
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    onPressed: () {
                      // UI only — video picker later.
                    },
                    child: Text(
                      l10n.aiVisionChooseBtn,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: MonitorGlassCard(
              padding: const EdgeInsets.all(10),
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Preview placeholder (camera / offline infer later).
                  ColoredBox(
                    color: const Color(0xFF101018),
                    child: Center(
                      child: Text(
                        l10n.liveVideoFailed,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // lws-ui top-right AI status chip.
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _AiStatusChip(
                      label: l10n.aiOverlayHudStatusPrefix(_demoHudStatus),
                    ),
                  ),
                  // lws-ui center Replace / Re-detect pills.
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PreviewPillButton(
                          label: l10n.aiVisionReplaceBtn,
                          onPressed: () {
                            // UI only — replace video later.
                          },
                        ),
                        const SizedBox(width: 20),
                        _PreviewPillButton(
                          label: l10n.aiVisionReinferBtn,
                          onPressed: () {
                            // UI only — re-detect later.
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-right “AI: CLEAN” style status chip (lws-ui HUD).
final class _AiStatusChip extends StatelessWidget {
  const _AiStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE60A1020),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiHexBadge(size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small hexagon “AI” glyph for the HUD chip.
final class _AiHexBadge extends StatelessWidget {
  const _AiHexBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _HexBorderPainter(color: Colors.white, strokeWidth: 1.2),
        child: Center(
          child: Text(
            'AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

final class _HexBorderPainter extends CustomPainter {
  const _HexBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2 - strokeWidth;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (60 * i - 30);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Frosted pill over the preview (Replace / Re-detect).
final class _PreviewPillButton extends StatelessWidget {
  const _PreviewPillButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          CyberClickSoundRegistry.playClick();
          onPressed();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: CyberDimens.actionButtonMediumHeight,
          decoration: BoxDecoration(
            color: const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // lws-ui: label on `#CC2E3653` bar; value below — not nested Frost cards.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AiVisionTab._labelBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 16),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE1E1E1),
                  fontSize: 24,
                  height: 1.0,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 16, 31, 0),
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE1E1E1),
                fontSize: 24,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
