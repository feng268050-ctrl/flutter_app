import 'package:flutter/material.dart';

/// Home-style extensible status icon row (transparent background).
///
/// Pass any ordered [items] (Wi‑Fi / BT / camera today; more later). Hidden
/// icons that return [SizedBox.shrink] still leave gaps unless omitted by the
/// caller — prefer omitting or using icon-internal shrink with conditional
/// inclusion as the product App does.
class CyberHomeStatusBar extends StatelessWidget {
  const CyberHomeStatusBar({
    super.key,
    required this.items,
    this.gap = 12,
    this.iconSize,
  });

  /// Status icon widgets left → right.
  final List<Widget> items;

  /// Horizontal gap between adjacent non-shrink items is applied between all
  /// list entries (including shrinks). Prefer filtering hidden icons in App.
  final double gap;

  /// Optional shared size hint for callers; not applied automatically — items
  /// own their size. Kept for API symmetry / future theming.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('cyber-home-status-bar'),
      // Explicit transparent plate so tests/docs can assert no opaque fill.
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            items[i],
          ],
        ],
      ),
    );
  }
}
