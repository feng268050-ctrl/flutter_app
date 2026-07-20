import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/ui/cyber/app_indexed_click_sound.dart';

/// Provides [SoundEffectStore] + [AppIndexedClickSound] under [AppScope].
final class SoundEffectScope extends InheritedWidget {
  const SoundEffectScope({
    super.key,
    required this.store,
    required this.clickSound,
    required super.child,
  });

  final SoundEffectStore store;
  final AppIndexedClickSound clickSound;

  static SoundEffectScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SoundEffectScope>();
    assert(scope != null, 'SoundEffectScope not found');
    return scope!;
  }

  static SoundEffectScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SoundEffectScope>();
  }

  @override
  bool updateShouldNotify(SoundEffectScope oldWidget) =>
      store != oldWidget.store || clickSound != oldWidget.clickSound;
}
