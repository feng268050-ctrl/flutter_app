import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_settings_ui/src/theme/settings_dimens.dart';
import 'package:flutter/material.dart';

/// One wallpaper preset for [SettingsWallpaperPicker].
@immutable
class SettingsWallpaperOption {
  const SettingsWallpaperOption({
    required this.id,
    required this.label,
    required this.imagePath,
  });

  final String id;
  final String label;
  final String imagePath;
}

/// Wallpaper carousel (PageView) + Apply. Applied preset shows a check badge.
class SettingsWallpaperPicker extends StatefulWidget {
  const SettingsWallpaperPicker({
    super.key,
    required this.options,
    required this.appliedId,
    required this.applyLabel,
    required this.onApply,
    this.busy = false,
    this.contentPadding = SettingsDimens.cardPadding,
    this.viewportFraction = 0.88,
  });

  final List<SettingsWallpaperOption> options;
  final String appliedId;
  final String applyLabel;
  final Future<void> Function(String id) onApply;
  final bool busy;

  /// Inset between the frosted card edge and picker content (uniform L/T/R/B).
  final EdgeInsetsGeometry contentPadding;

  /// Visible width of each carousel slide (0–1 of viewport).
  final double viewportFraction;

  @override
  State<SettingsWallpaperPicker> createState() =>
      _SettingsWallpaperPickerState();
}

class _SettingsWallpaperPickerState extends State<SettingsWallpaperPicker> {
  late String _selectedId;
  late PageController _pageController;

  int _indexForId(String id) {
    final i = widget.options.indexWhere((o) => o.id == id);
    return i >= 0 ? i : 0;
  }

  SettingsWallpaperOption? _optionForId(String id) {
    for (final o in widget.options) {
      if (o.id == id) {
        return o;
      }
    }
    return widget.options.isEmpty ? null : widget.options.first;
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.appliedId;
    _pageController = PageController(
      initialPage: _indexForId(_selectedId),
      viewportFraction: widget.viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsWallpaperPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appliedId != widget.appliedId &&
        _selectedId == oldWidget.appliedId) {
      _selectedId = widget.appliedId;
      _jumpToSelected(animate: false);
    }
    if (oldWidget.viewportFraction != widget.viewportFraction &&
        _pageController.viewportFraction != widget.viewportFraction) {
      final page = _pageController.hasClients
          ? (_pageController.page ?? _indexForId(_selectedId).toDouble())
          : _indexForId(_selectedId).toDouble();
      _pageController.dispose();
      _pageController = PageController(
        initialPage: page.round().clamp(0, widget.options.length - 1),
        viewportFraction: widget.viewportFraction,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToSelected({required bool animate}) {
    if (!_pageController.hasClients || widget.options.isEmpty) {
      return;
    }
    final index = _indexForId(_selectedId);
    if (animate) {
      unawaited(
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  bool get _dirty => _selectedId != widget.appliedId;

  Future<void> _apply() async {
    if (widget.busy || !_dirty) {
      return;
    }
    await widget.onApply(_selectedId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedIndex = _indexForId(_selectedId);
    final selectedOption = _optionForId(_selectedId);

    return Padding(
      padding: widget.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.options.length,
              onPageChanged: widget.busy
                  ? null
                  : (index) {
                      CyberClickSoundRegistry.playClick();
                      setState(
                        () => _selectedId = widget.options[index].id,
                      );
                    },
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final applied = option.id == widget.appliedId;
                final focused = index == selectedIndex;
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(focused ? 4 : 8),
                  child: _WallpaperSlide(
                    option: option,
                    applied: applied,
                    focused: focused,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == selectedIndex ? 8 : 6,
                    height: i == selectedIndex ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == selectedIndex
                          ? CyberColors.textPrimary
                          : CyberColors.textSecondary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
            ],
          ),
          if (selectedOption != null) ...[
            const SizedBox(height: 10),
            Text(
              selectedOption.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CyberColors.textPrimary,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: CyberButton(
              onPressed:
                  !widget.busy && _dirty ? () => unawaited(_apply()) : null,
              child: Text(widget.applyLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _WallpaperSlide extends StatelessWidget {
  const _WallpaperSlide({
    required this.option,
    required this.applied,
    required this.focused,
  });

  final SettingsWallpaperOption option;
  final bool applied;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.label,
      selected: focused,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused
                    ? CyberColors.textPrimary
                    : const Color(0x44FFFFFF),
                width: focused ? 2 : 1,
              ),
              boxShadow: focused
                  ? const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: _WallpaperThumbnail(path: option.imagePath),
            ),
          ),
          if (applied)
            Positioned(
              right: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.check,
                    size: 20,
                    color: CyberColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WallpaperThumbnail extends StatelessWidget {
  const _WallpaperThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return const ColoredBox(color: Color(0xFF1A1C22));
    }
    final file = File(trimmed);
    if (!file.existsSync()) {
      return const ColoredBox(color: Color(0xFF1A1C22));
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1C22)),
    );
  }
}
