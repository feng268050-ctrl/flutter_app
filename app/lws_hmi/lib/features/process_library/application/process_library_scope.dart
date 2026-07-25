import 'package:flutter/widgets.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';

final class ProcessLibraryScope
    extends InheritedNotifier<ProcessLibraryController> {
  const ProcessLibraryScope({
    super.key,
    required ProcessLibraryController controller,
    required super.child,
  }) : super(notifier: controller);

  static ProcessLibraryController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ProcessLibraryScope>();
    assert(scope != null, 'ProcessLibraryScope not found');
    return scope!.notifier!;
  }
}
