import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_thresholds_controller.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';

/// Provides [AdvancedSettingsStore], facades, and threshold controller.
final class AdvancedSettingsScope extends InheritedWidget {
  const AdvancedSettingsScope({
    super.key,
    required this.store,
    required this.aiAssistance,
    required this.dangerousOperations,
    required this.thresholds,
    required super.child,
  });

  final AdvancedSettingsStore store;
  final AiAssistanceSettings aiAssistance;
  final DangerousOperationsSettings dangerousOperations;
  final AdvancedSettingsThresholdsController thresholds;

  static AdvancedSettingsStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>();
    assert(scope != null, 'AdvancedSettingsScope not found');
    return scope!.store;
  }

  static AdvancedSettingsStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>()
        ?.store;
  }

  static AiAssistanceSettings aiOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>();
    assert(scope != null, 'AdvancedSettingsScope not found');
    return scope!.aiAssistance;
  }

  static AiAssistanceSettings? maybeAiOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>()
        ?.aiAssistance;
  }

  static DangerousOperationsSettings dangerousOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>();
    assert(scope != null, 'AdvancedSettingsScope not found');
    return scope!.dangerousOperations;
  }

  static DangerousOperationsSettings? maybeDangerousOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>()
        ?.dangerousOperations;
  }

  static AdvancedSettingsThresholdsController thresholdsOf(
    BuildContext context,
  ) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>();
    assert(scope != null, 'AdvancedSettingsScope not found');
    return scope!.thresholds;
  }

  static AdvancedSettingsThresholdsController? maybeThresholdsOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<AdvancedSettingsScope>()
        ?.thresholds;
  }

  @override
  bool updateShouldNotify(AdvancedSettingsScope oldWidget) =>
      store != oldWidget.store ||
      aiAssistance != oldWidget.aiAssistance ||
      dangerousOperations != oldWidget.dangerousOperations ||
      thresholds != oldWidget.thresholds;
}
