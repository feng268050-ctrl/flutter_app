import 'package:flutter/widgets.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';

/// App-root access to the process-wide [GlobalPromptQueue].
final class GlobalPromptScope extends InheritedWidget {
  const GlobalPromptScope({
    super.key,
    required this.queue,
    required super.child,
  });

  final GlobalPromptQueue queue;

  static GlobalPromptQueue of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GlobalPromptScope>();
    assert(scope != null, 'GlobalPromptScope not found');
    return scope!.queue;
  }

  static GlobalPromptQueue? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalPromptScope>()
        ?.queue;
  }

  @override
  bool updateShouldNotify(GlobalPromptScope oldWidget) =>
      queue != oldWidget.queue;
}
