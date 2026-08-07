import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_tab_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_primary_tab_content.dart';

/// Item layout for [ProductTopTabs].
enum ProductTopTabLayout {
  /// Monitor: compact icon+label group centered in the cell.
  monitorPinnedIcon,

  /// Legacy Settings strip sizing (same content group as Monitor).
  lwsUi,
}

/// Shared product top-tab strip (Settings legacy layout / Monitor).
///
/// Opaque strip ([background]) so Home wallpaper does not show through.
/// A hairline under the strip matches Settings / Monitor card inset
/// ([dividerInset]).
final class ProductTopTabs extends StatefulWidget
    implements PreferredSizeWidget {
  const ProductTopTabs({
    super.key,
    required this.labels,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    this.layout = ProductTopTabLayout.monitorPinnedIcon,
    this.backgroundColor,
  });

  /// Opaque tab strip — matches Settings top tabs.
  static const background = CyberColors.fillSolidTop;

  static const sidePadding = 4.0;

  /// Hairline under the strip — matches Settings / Monitor card inset (24).
  static const dividerThickness = 1.0;
  static const dividerColor = Color(0x33FFFFFF);
  static const dividerInset = 24.0;

  /// Monitor strip height (aligned with Settings / Engineer).
  static const monitorHeight = HmiTabMetrics.tabHeight;

  /// Settings strip height (aligned with Monitor).
  static const lwsUiHeight = HmiTabMetrics.tabHeight;

  /// Monitor min width (wider than lws-ui 236 for fontSize 24).
  static const monitorMinTabWidth = 280.0;

  /// lws-ui `top_tab_item_width`.
  static const lwsUiMinTabWidth = 236.0;

  final List<String> labels;
  final List<({Key key, IconData icon})> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ProductTopTabLayout layout;

  /// Optional page backdrop. Monitor keeps this transparent so the shared
  /// wallpaper continues behind the status bar and tab strip.
  final Color? backgroundColor;

  double get height =>
      layout == ProductTopTabLayout.lwsUi ? lwsUiHeight : monitorHeight;

  @override
  Size get preferredSize => Size.fromHeight(height + dividerThickness);

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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensureSelectedVisible());
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
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: HmiTabMetrics.labelFontSize,
          fontWeight: HmiTabMetrics.labelWeight,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final contentWidth = HmiTabMetrics.horizontalPadding * 2 +
        HmiTabMetrics.iconSize +
        HmiTabMetrics.iconLabelGap +
        painter.width;
    final minWidth = widget.layout == ProductTopTabLayout.lwsUi
        ? ProductTopTabs.lwsUiMinTabWidth
        : ProductTopTabs.monitorMinTabWidth;
    return math.max(minWidth, contentWidth);
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
          onTap: () => widget.onSelected(i),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widths = _tabWidths();
    return ColoredBox(
      color: widget.backgroundColor ?? ProductTopTabs.background,
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
    required this.onTap,
  });

  static const unselectedLwsUi = Color(0xFF94A3B8);

  final String label;
  final IconData icon;
  final bool selected;
  final ProductTopTabLayout layout;
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: HmiPrimaryTabContent(
                icon: Icon(
                  icon,
                  size: HmiTabMetrics.iconSize,
                  color: color,
                ),
                label: label,
                color: color,
                selected: selected,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: HmiTabMetrics.indicatorHeight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                color: selected ? Colors.white : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
