import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Translates [child] upward by [liftExtent] without resizing the parent.
///
/// Used to lift Cyber dialog cards above a CyberIME keyboard panel.
class CyberLiftedPanel extends StatelessWidget {
  const CyberLiftedPanel({
    super.key,
    required this.liftExtent,
    required this.child,
  });

  /// Keyboard height + margin (logical pixels). Zero = no translation.
  final ValueListenable<double> liftExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: liftExtent,
      builder: (context, lift, child) {
        return Transform.translate(
          offset: Offset(0, -lift),
          child: child,
        );
      },
      child: child,
    );
  }
}
