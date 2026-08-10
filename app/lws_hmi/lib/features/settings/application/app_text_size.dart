import 'package:lws_hmi/app/theme/hmi_text_scale.dart';

/// Operator-selectable reading text size (Common Settings).
enum AppTextSize {
  small,
  medium,
  large;

  /// Linear [MediaQuery.textScaler] factor for reading UI.
  double get scale => switch (this) {
        AppTextSize.small => HmiTextScale.readingSmall,
        AppTextSize.medium => HmiTextScale.readingMedium,
        AppTextSize.large => HmiTextScale.readingLarge,
      };

  /// JSON / wire value (`small` | `medium` | `large`).
  String get wire => name;

  static const defaultSize = AppTextSize.medium;

  static const supported = <AppTextSize>[
    AppTextSize.small,
    AppTextSize.medium,
    AppTextSize.large,
  ];

  static AppTextSize parse(String? raw) {
    switch (raw) {
      case 'small':
        return AppTextSize.small;
      case 'large':
        return AppTextSize.large;
      case 'medium':
        return AppTextSize.medium;
      default:
        return defaultSize;
    }
  }
}
