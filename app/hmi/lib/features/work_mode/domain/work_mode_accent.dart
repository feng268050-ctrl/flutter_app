import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Theme accent for work-mode chrome (lws-ui quick_model_* / EquipmentStatusBar).
enum WorkModeAccentFamily { weld, clean, cut }

/// Resolved colors for the work-mode Back rail (edge lines + press fill).
final class WorkModeAccent {
  const WorkModeAccent._({
    required this.family,
    required this.solid,
    required this.pressCenter,
  });

  /// Continuous / spot weld — lws-ui `quick_model_orange` (#F46E01).
  static const weld = WorkModeAccent._(
    family: WorkModeAccentFamily.weld,
    solid: Color(0xFFF46E01),
    pressCenter: Color(0xB2FF8000),
  );

  /// Weld-path / ultra-wide clean — lws-ui `quick_model_green` (#37F3D2).
  static const clean = WorkModeAccent._(
    family: WorkModeAccentFamily.clean,
    solid: Color(0xFF37F3D2),
    pressCenter: Color(0x8037F3D2),
  );

  /// Hand / CNC cut — lws-ui `quick_model_blue` (#0151F4).
  static const cut = WorkModeAccent._(
    family: WorkModeAccentFamily.cut,
    solid: Color(0xFF0151F4),
    pressCenter: Color(0x800151F4),
  );

  /// Disabled chrome — lws-ui `side_tab_not_active_color` (#909399).
  static const disabled = WorkModeAccent._(
    family: WorkModeAccentFamily.weld,
    solid: Color(0xFF909399),
    pressCenter: Color(0x00909399),
  );

  final WorkModeAccentFamily family;
  final Color solid;
  final Color pressCenter;

  /// Top/bottom hairline: transparent → solid → transparent (lws-ui line_gradient_*).
  LinearGradient get edgeGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          solid.withOpacity(0),
          solid,
          solid.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Pressed fill: transparent → translucent solid → transparent
  /// (lws-ui `quick_mode_wheel_active_*`).
  LinearGradient get pressGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          pressCenter.withOpacity(0),
          pressCenter,
          pressCenter.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  static WorkModeAccent forProcessType(ProcessType? processType) {
    if (processType == null) {
      return weld;
    }
    if (processType.isCleaning) {
      return clean;
    }
    if (processType == ProcessType.handCutting ||
        processType == ProcessType.cncCutting) {
      return cut;
    }
    return weld;
  }
}
