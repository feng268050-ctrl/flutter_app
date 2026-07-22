import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';

/// Provides [AdvancedSettingsStore] and facades under the app tree.
final class AdvancedSettingsScope extends InheritedWidget {
  const AdvancedSettingsScope({
    super.key,
    required this.store,
    required this.aiAssistance,
    required this.dangerousOperations,
    required super.child,
  });

  final AdvancedSettingsStore store;
  final AiAssistanceSettings aiAssistance;
  final DangerousOperationsSettings dangerousOperations;

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

  @override
  bool updateShouldNotify(AdvancedSettingsScope oldWidget) =>
      store != oldWidget.store ||
      aiAssistance != oldWidget.aiAssistance ||
      dangerousOperations != oldWidget.dangerousOperations;
}
