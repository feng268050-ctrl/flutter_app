import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_settings_ui/cyber_settings_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/settings/application/app_text_size.dart';
import 'package:lws_hmi/features/settings/application/text_size_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/text_size_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_pill_dropdown.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Display settings — brightness, auto screen-off, wallpaper, and text size.
/// UI scale (`display.conf` `ui_scale`) is OS Settings only — see
/// `docs/settings-apps-roles.md`.
class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  double _brightness = 80;
  AutoSleepPolicy _screenOff = AutoSleepPolicy.never;
  bool _loadingScreenOff = true;
  bool _busyBrightness = false;
  int? _queuedBrightness;
  List<WallpaperPreset> _wallpapers = const [];
  String? _appliedWallpaperId;
  bool _loadingWallpaper = true;
  bool _wallpaperBusy = false;

  List<SettingsPillOption<AutoSleepPolicy>> _screenOffOptions(
    AppLocalizations l10n,
  ) =>
      [
        SettingsPillOption(
          value: AutoSleepPolicy.minutes10,
          label: l10n.screenOffOption10Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.minutes30,
          label: l10n.screenOffOption30Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.minutes60,
          label: l10n.screenOffOption60Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.never,
          label: l10n.screenOffNever,
        ),
      ];

  String _wallpaperLabel(AppLocalizations l10n, WallpaperPreset preset) {
    if (preset.id == 'home_back') {
      return l10n.wallpaperOptionDefault;
    }
    return preset.label;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadBrightness());
      unawaited(_loadScreenOff());
      unawaited(_loadWallpaper());
    });
  }

  Future<void> _loadBrightness() async {
    try {
      final v = await widget.services.backlight.getBrightnessPercent();
      if (mounted) setState(() => _brightness = v.toDouble());
    } catch (_) {}
  }

  Future<void> _loadScreenOff() async {
    try {
      final policy = await widget.services.autoSleep.getPolicy();
      if (!mounted) return;
      setState(() {
        _screenOff = policy;
        _loadingScreenOff = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingScreenOff = false);
    }
  }

  Future<void> _loadWallpaper() async {
    try {
      final wallpaper = widget.services.wallpaper;
      wallpaper.warmRead();
      final presets = await wallpaper.listPresets();
      var id = wallpaper.activePresetId.trim();
      if (id.isEmpty && presets.isNotEmpty) {
        id = presets.first.id;
      }
      if (!mounted) return;
      setState(() {
        _wallpapers = presets;
        _appliedWallpaperId = id.isEmpty ? null : id;
        _loadingWallpaper = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWallpaper = false);
    }
  }

  Future<void> _drainBrightness() async {
    if (_busyBrightness) return;
    final next = _queuedBrightness;
    if (next == null) return;
    _queuedBrightness = null;
    _busyBrightness = true;
    try {
      await widget.services.backlight.setBrightnessPercent(next);
    } catch (_) {
    } finally {
      _busyBrightness = false;
      if (_queuedBrightness != null) unawaited(_drainBrightness());
    }
  }

  Future<void> _setScreenOff(AutoSleepPolicy policy) async {
    setState(() => _screenOff = policy);
    await widget.services.autoSleep.setPolicy(policy);
  }

  Future<void> _applyWallpaper(String presetId) async {
    setState(() => _wallpaperBusy = true);
    try {
      await widget.services.wallpaper.setPreset(presetId);
      if (mounted) {
        setState(() => _appliedWallpaperId = presetId);
      }
    } finally {
      if (mounted) {
        setState(() => _wallpaperBusy = false);
      }
    }
  }

  List<SettingsWallpaperOption> _wallpaperOptions(AppLocalizations l10n) => [
        for (final p in _wallpapers)
          SettingsWallpaperOption(
            id: p.id,
            label: _wallpaperLabel(l10n, p),
            imagePath: p.path,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = _screenOffOptions(l10n);
    final selectedLabel = options
        .firstWhere(
          (o) => o.value == _screenOff,
          orElse: () => options.last,
        )
        .label;
    final appliedId = _appliedWallpaperId ??
        (_wallpapers.isEmpty ? '' : _wallpapers.first.id);

    return SettingsScaffold(
      title: l10n.screenSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSliderRow(
                title: l10n.screenBrightnessText,
                child: CyberSlider(
                  value: _brightness.clamp(0, 100),
                  min: 0,
                  max: 100,
                  showDragValueLabel: true,
                  onChanged: (v) => setState(() => _brightness = v),
                  onChangeEnd: (v) {
                    _queuedBrightness = v.round();
                    unawaited(_drainBrightness());
                  },
                ),
              ),
              SettingsControlRow(
                title: l10n.screenOffTimeText,
                control: SettingsPillDropdown<AutoSleepPolicy>(
                  value: _screenOff,
                  label: selectedLabel,
                  options: options,
                  enabled: !_loadingScreenOff,
                  onChanged: (v) => unawaited(_setScreenOff(v)),
                ),
              ),
            ],
          ),
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topRightBottomLeft,
            children: const [_TextSizeSliderCard()],
          ),
          if (_wallpapers.isNotEmpty && appliedId.isNotEmpty) ...[
            SettingsSectionHeader(l10n.wallpaperSettingText),
            SettingsGroup(
              bottomInset: 0,
              children: [
                SettingsWallpaperPicker(
                  options: _wallpaperOptions(l10n),
                  appliedId: appliedId,
                  applyLabel: l10n.wifiApply,
                  busy: _loadingWallpaper || _wallpaperBusy,
                  onApply: _applyWallpaper,
                ),
              ],
            ),
            SettingsHelpFooter(l10n.wallpaperApplyRestarts),
          ],
        ],
      ),
    );
  }
}

/// Discrete text-size control. Its local value deliberately does not update
/// [TextSizeSettingsStore] until the gesture ends, so the app's MediaQuery scale
/// cannot relayout this page while the thumb is being dragged.
class _TextSizeSliderCard extends StatefulWidget {
  const _TextSizeSliderCard();

  @override
  State<_TextSizeSliderCard> createState() => _TextSizeSliderCardState();
}

class _TextSizeSliderCardState extends State<_TextSizeSliderCard> {
  AppTextSize? _localSize;

  AppTextSize get _selectedSize =>
      _localSize ??
      TextSizeSettingsScope.maybeOf(context)?.textSize ??
      TextSizeSettingsStore.defaultTextSize;

  static double _sliderValue(AppTextSize size) =>
      TextSizeSettingsStore.supportedTextSizes.indexOf(size).toDouble();

  static AppTextSize _sizeForSliderValue(double value) {
    final index = value
        .round()
        .clamp(0, TextSizeSettingsStore.supportedTextSizes.length - 1)
        .toInt();
    return TextSizeSettingsStore.supportedTextSizes[index];
  }

  void _select(double value) {
    setState(() => _localSize = _sizeForSliderValue(value));
  }

  void _commit(double value) {
    final size = _sizeForSliderValue(value);
    setState(() => _localSize = size);
    final store = TextSizeSettingsScope.maybeOf(context);
    if (store != null) {
      unawaited(store.setTextSize(size));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = TextSizeSettingsScope.maybeOf(context);
    final selected = _selectedSize;
    final storeSize = store?.textSize ?? TextSizeSettingsStore.defaultTextSize;
    final labelStyle = context.hmiTypography.settingsRowTitle;
    // Preview the slider selection without double-scaling after commit: MediaQuery
    // already tracks [storeSize]; bump labels only by the delta to [selected].
    final labelScaler = TextScaler.linear(selected.scale / storeSize.scale);
    final labels = <String>[
      l10n.textSizeOptionSmall,
      l10n.defaultLabel,
      l10n.textSizeOptionLarge,
    ];
    final trackInset =
        CyberSliderLogic.thumbDragOverflow + CyberSliderLogic.thumbSize / 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.textSizeSettingText,
            style: labelStyle.copyWith(
              color: CyberColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          CyberSlider(
            value: _sliderValue(selected),
            min: 0,
            max: 2,
            divisions: 2,
            showTickMarks: true,
            tapToSelect: true,
            longPressDragEnabled: false,
            enabled: store != null,
            onChanged: _select,
            onChangeEnd: _commit,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: trackInset),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _sliderValue(selected) == i,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: store == null
                              ? null
                              : () {
                                  CyberClickSoundRegistry.playClick();
                                  _commit(i.toDouble());
                                },
                          child: Align(
                            alignment: switch (i) {
                              0 => Alignment.centerLeft,
                              1 => Alignment.center,
                              _ => Alignment.centerRight,
                            },
                            child: Text(
                              labels[i],
                              textScaler: labelScaler,
                              style: labelStyle.copyWith(
                                color: _sliderValue(selected) == i
                                    ? CyberColors.textPrimary
                                    : CyberColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
