import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Item layout for [ProductTopTabs].
enum ProductTopTabLayout {
  /// Monitor: text centered; icon pinned with equal L/T/B inset.
  monitorPinnedIcon,

  /// Settings (lws-ui sizes): text centered; icon pinned with equal L/T/B inset.
  lwsUi,
}

/// Shared product top-tab strip (Settings legacy layout / Monitor).
///
/// Strip fill follows [ThemeData.scaffoldBackgroundColor] (theme gray), not
/// the former lws-ui `job_border1` navy plate. A hairline under the strip
/// matches Settings / Monitor card inset ([dividerInset]).
final class ProductTopTabs extends StatefulWidget
    implements PreferredSizeWidget {
  const ProductTopTabs({
    super.key,
    required this.labels,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    this.layout = ProductTopTabLayout.monitorPinnedIcon,
  });

  static const sidePadding = 4.0;

  /// Hairline under the strip — matches Settings / Monitor card inset (24).
  static const dividerThickness = 1.0;
  static const dividerColor = Color(0x33FFFFFF);
  static const dividerInset = 24.0;

  /// Monitor strip height (slightly under lws-ui; −10 vs prior 78).
  static const monitorHeight = 68.0;

  /// Settings strip height (aligned with Monitor).
  static const lwsUiHeight = 68.0;

  /// Monitor min width (wider than lws-ui 236 for fontSize 24).
  static const monitorMinTabWidth = 280.0;

  /// lws-ui `top_tab_item_width`.
  static const lwsUiMinTabWidth = 236.0;

  final List<String> labels;
  final List<({Key key, IconData icon})> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ProductTopTabLayout layout;

  double get height => layout == ProductTopTabLayout.lwsUi
      ? lwsUiHeight
      : monitorHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + dividerThickness);

  @override
  State<ProductTopTabs> createState() => _ProductTopTabsState();
}

final class _ProductTopTabsState extends State<ProductTopTabs> {
  final _scrollController = ScrollController();
  final _itemKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncItemKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelectedVisible());
  }

  @override
  void didUpdateWidget(covariant ProductTopTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemKeys();
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.labels != widget.labels ||
        oldWidget.layout != widget.layout) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureSelectedVisible());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncItemKeys() {
    while (_itemKeys.length < widget.tabs.length) {
      _itemKeys.add(GlobalKey());
    }
    if (_itemKeys.length > widget.tabs.length) {
      _itemKeys.removeRange(widget.tabs.length, _itemKeys.length);
    }
  }

  void _ensureSelectedVisible() {
    if (!mounted ||
        widget.currentIndex < 0 ||
        widget.currentIndex >= _itemKeys.length ||
        !_scrollController.hasClients) {
      return;
    }
    final ctx = _itemKeys[widget.currentIndex].currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  double _tabWidthFor(String label) {
    if (widget.layout == ProductTopTabLayout.lwsUi) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: _ProductTopTabItem.lwsUiFontSize,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      const iconSize = _ProductTopTabItem.lwsUiIconSize;
      final iconInset = (ProductTopTabs.lwsUiHeight - iconSize) / 2;
      final side = iconInset + iconSize + _ProductTopTabItem.iconTextGap;
      return math.max(
        ProductTopTabs.lwsUiMinTabWidth,
        painter.width + 2 * side,
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: _ProductTopTabItem.monitorFontSize,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    const iconSize = _ProductTopTabItem.monitorIconSize;
    final iconInset = (ProductTopTabs.monitorHeight - iconSize) / 2;
    final side = iconInset + iconSize + _ProductTopTabItem.iconTextGap;
    return math.max(
      ProductTopTabs.monitorMinTabWidth,
      painter.width + 2 * side,
    );
  }

  List<double> _tabWidths() =>
      [for (final label in widget.labels) _tabWidthFor(label)];

  Widget _tabAt(int i, double width) {
    return KeyedSubtree(
      key: _itemKeys[i],
      child: SizedBox(
        width: width,
        child: _ProductTopTabItem(
          key: widget.tabs[i].key,
          label: widget.labels[i],
          icon: widget.tabs[i].icon,
          selected: i == widget.currentIndex,
          layout: widget.layout,
          stripHeight: widget.height,
          onTap: () => widget.onSelected(i),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widths = _tabWidths();
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // lws-ui `tabGravity=center`: center the group when it fits.
                if (widget.layout == ProductTopTabLayout.lwsUi) {
                  final total = widths.fold<double>(0, (a, b) => a + b) +
                      ProductTopTabs.sidePadding * 2;
                  if (total <= constraints.maxWidth) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ProductTopTabs.sidePadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.tabs.length; i++)
                            _tabAt(i, widths[i]),
                        ],
                      ),
                    );
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ProductTopTabs.sidePadding,
                  ),
                  itemCount: widget.tabs.length,
                  itemBuilder: (context, i) => _tabAt(i, widths[i]),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ProductTopTabs.dividerInset,
            ),
            child: ColoredBox(
              color: ProductTopTabs.dividerColor,
              child: SizedBox(
                height: ProductTopTabs.dividerThickness,
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProductTopTabItem extends StatelessWidget {
  const _ProductTopTabItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.layout,
    required this.stripHeight,
    required this.onTap,
  });

  static const monitorIconSize = 31.0;
  static const monitorFontSize = 24.0;
  static const lwsUiIconSize = 31.0;
  static const lwsUiFontSize = 27.0;
  static const iconTextGap = 6.0;
  static const unselectedLwsUi = Color(0xFF94A3B8);

  final String label;
  final IconData icon;
  final bool selected;
  final ProductTopTabLayout layout;
  final double stripHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : (layout == ProductTopTabLayout.lwsUi
            ? unselectedLwsUi
            : Colors.white60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: layout == ProductTopTabLayout.lwsUi
            ? _buildLwsUi(color)
            : _buildMonitorPinned(color),
      ),
    );
  }

  Widget _buildLwsUi(Color color) {
    final iconInset = (stripHeight - lwsUiIconSize) / 2;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: lwsUiFontSize,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    // Underline tracks the centered label (icon is pinned separately).
    final underlineWidth = textPainter.width;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: lwsUiFontSize,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              height: 1.0,
            ),
          ),
        ),
        Positioned(
          left: iconInset,
          top: iconInset,
          width: lwsUiIconSize,
          height: lwsUiIconSize,
          child: Icon(icon, size: lwsUiIconSize, color: color),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2,
              width: selected ? underlineWidth : 0,
              color: selected ? Colors.white : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitorPinned(Color color) {
    final iconInset = (stripHeight - monitorIconSize) / 2;
    return Stack(
      children: [
        Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: monitorFontSize,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              height: 1.0,
            ),
          ),
        ),
        Positioned(
          left: iconInset,
          top: iconInset,
          width: monitorIconSize,
          height: monitorIconSize,
          child: Icon(icon, size: monitorIconSize, color: color),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 2,
            color: selected ? Colors.white : Colors.transparent,
          ),
        ),
      ],
    );
  }
}
