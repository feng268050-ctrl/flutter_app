import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// App-local content panel for Engineer Mode — same chrome as Settings plates
/// under [SettingsBlurredPageShell] ([SettingsPerspectiveChrome]).
///
/// [edge] maps to [SettingsPanel.borderGradientCenter] for call-site
/// compatibility (uniform rim ignores gradient direction).
enum EngineerFrostEdge { topLeftBottomRight, bottomLeftTopRight }

final class EngineerFrostPanel extends StatelessWidget {
  const EngineerFrostPanel({
    super.key,
    required this.child,
    required this.edge,
  });

  final Widget child;
  final EngineerFrostEdge edge;

  /// Shared solid bright-edge stroke across Engineer / Monitor panels.
  static const edgeWidth = SettingsPerspectiveChrome.strokeWidth;
  static const edgeColor = SettingsPerspectiveChrome.strokeColor;

  @override
  Widget build(BuildContext context) {
    final center = switch (edge) {
      EngineerFrostEdge.topLeftBottomRight =>
        CyberBorderGradientCenter.topLeftBottomRight,
      EngineerFrostEdge.bottomLeftTopRight =>
        CyberBorderGradientCenter.bottomLeftTopRight,
    };
    return SettingsPanel(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderGradientCenter: center,
      child: child,
    );
  }
}
