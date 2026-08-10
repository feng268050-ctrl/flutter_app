import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/gpio_config.dart';
import 'package:cyber_hal/src/gpio/gpiod_logical_line.dart';
import 'package:cyber_hal/src/gpio/logical_line.dart';
import 'package:cyber_hal/src/gpio/stub_logical_line.dart';
import 'package:cyber_hal/src/gpio/sysfs_logical_line.dart';

/// Opens [LogicalGpioLine] instances from config bindings.
final class DefaultLogicalGpioLineFactory implements LogicalGpioLineFactory {
  DefaultLogicalGpioLineFactory({this.forceStub = false});

  final bool forceStub;

  final Map<String, StubLogicalGpioLine> stubLines = {};

  @override
  LogicalGpioLine open({
    required String id,
    required GpioLineBinding binding,
    required bool defaultActiveLow,
    required bool asInput,
  }) {
    final scheme =
        forceStub ? GpioBindingScheme.stub : binding.scheme;

    switch (scheme) {
      case GpioBindingScheme.stub:
        return stubLines.putIfAbsent(
          id,
          () => StubLogicalGpioLine(id),
        );
      case GpioBindingScheme.sysfs:
      case GpioBindingScheme.sysfsExport:
        return SysfsLogicalGpioLine(
          id: id,
          binding: binding.scheme == GpioBindingScheme.sysfsExport
              ? binding
              : GpioLineBinding(
                  scheme: binding.scheme == GpioBindingScheme.sysfsExport
                      ? GpioBindingScheme.sysfsExport
                      : GpioBindingScheme.sysfs,
                  label: binding.label,
                  path: binding.path,
                  fallbackLinuxGpio: binding.fallbackLinuxGpio,
                  chip: binding.chip,
                  chipLabel: binding.chipLabel,
                  offset: binding.offset,
                  activeLow: binding.activeLow,
                ),
          defaultActiveLow: defaultActiveLow,
        );
      case GpioBindingScheme.gpiod:
        return GpiodLogicalGpioLine(
          id: id,
          binding: binding,
          defaultActiveLow: defaultActiveLow,
          asInput: asInput,
        );
    }
  }
}

LogicalGpioLine openLogicalLineOrThrow({
  required LogicalGpioLineFactory factory,
  required String id,
  required GpioLineBinding binding,
  required bool defaultActiveLow,
  required bool asInput,
}) {
  try {
    return factory.open(
      id: id,
      binding: binding,
      defaultActiveLow: defaultActiveLow,
      asInput: asInput,
    );
  } on HalException {
    rethrow;
  } catch (e) {
    throw HalIoException('gpio $id open failed: $e', cause: e);
  }
}
