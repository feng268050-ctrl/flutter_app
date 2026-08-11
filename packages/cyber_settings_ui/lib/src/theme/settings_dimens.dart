import 'package:flutter/material.dart';

/// Layout tokens shared by OS Settings and HMI Settings chrome.
abstract final class SettingsDimens {
  static const inset = 24.0;
  static const groupGap = inset;
  static const rowMinHeight = 70.0;
  static const rowPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 8);
  static const cardPadding = EdgeInsets.all(20);
  static const titleSize = 20.0;
}
