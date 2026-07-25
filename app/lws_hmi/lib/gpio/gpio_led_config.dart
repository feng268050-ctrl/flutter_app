import 'package:cyber_hal/gpio.dart';

/// Resolve Demo caption pin text from loaded [GpioConfig].
String gpioLedPinCaption(GpioConfig config) {
  String labelOf(String id) => config.lineById(id)?.label ?? id;
  String linuxOf(String id) =>
      '${config.lineById(id)?.fallbackLinuxGpio ?? '?'}';
  return 'Pins R/Y/G ${labelOf('led_red')}/'
      '${labelOf('led_yellow')}/${labelOf('led_green')} → '
      'linux ${linuxOf('led_red')}/'
      '${linuxOf('led_yellow')}/${linuxOf('led_green')}';
}
