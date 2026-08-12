import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

import '../theme/settings_dimens.dart';
import '../theme/settings_typography.dart';
import 'settings_card_ink.dart';

/// Single layout authority for a Settings list item.
class SettingsRowFrame extends StatelessWidget {
  const SettingsRowFrame({
    super.key,
    required this.child,
    this.onTap,
    this.clickSoundEnabled = true,
    this.padding = SettingsDimens.rowPadding,
    this.minHeight,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool clickSoundEnabled;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final typography = SettingsTypography.of(context);
    final splashRadius = SettingsCardInk.maybeOf(context)?.splashBorderRadius;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight ?? typography.rowMinHeight,
      ),
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: double.infinity,
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );
    if (onTap == null) {
      return content;
    }

    final ink = InkWell(
      borderRadius: splashRadius,
      onTap: () {
        if (clickSoundEnabled) {
          CyberClickSoundRegistry.playClick();
        }
        onTap!();
      },
      child: content,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: splashRadius,
      clipBehavior: Clip.none,
      child: ink,
    );
  }
}
