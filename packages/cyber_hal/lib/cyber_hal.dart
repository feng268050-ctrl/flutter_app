/// cyber_hal — portable Dart HAL for LWS appliance HMIs.
///
/// Prefer domain imports for product code:
///
/// ```dart
/// import 'package:cyber_hal/output/backlight.dart';
/// import 'package:cyber_hal/gpio.dart';
/// ```
///
/// This barrel re-exports core discovery types only.
library;

export 'src/core/board_info.dart';
export 'src/core/capabilities.dart';
export 'src/core/errors.dart';
export 'src/core/net_role.dart';
export 'src/display/display_stack.dart';
export 'src/profile/board_bindings.dart';
export 'src/profile/board_profile.dart';

