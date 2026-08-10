import 'package:flutter/widgets.dart';
import 'package:lws_hmi/features/settings/application/text_size_settings_store.dart';

final class TextSizeSettingsScope extends InheritedWidget {
  const TextSizeSettingsScope({
    super.key,
    required this.store,
    required super.child,
  });

  final TextSizeSettingsStore store;

  static TextSizeSettingsStore? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TextSizeSettingsScope>()
      ?.store;

  @override
  bool updateShouldNotify(TextSizeSettingsScope oldWidget) =>
      store != oldWidget.store;
}
