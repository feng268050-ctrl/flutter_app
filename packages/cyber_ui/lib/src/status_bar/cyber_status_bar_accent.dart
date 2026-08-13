import 'package:flutter/material.dart';

/// Resolved colors for product status-bar Back rail (edge lines + press fill).
final class CyberStatusBarAccent {
  const CyberStatusBarAccent({
    required this.solid,
    required this.pressCenter,
  });

  /// Product weld orange — lws-ui `quick_model_orange` (#F46E01).
  static const weld = CyberStatusBarAccent(
    solid: Color(0xFFF46E01),
    pressCenter: Color(0xFFF46E01),
  );

  final Color solid;
  final Color pressCenter;

  LinearGradient get edgeGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          solid.withValues(alpha: 0),
          solid,
          solid.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  LinearGradient get pressGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          pressCenter.withValues(alpha: 0),
          pressCenter,
          pressCenter.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
}
