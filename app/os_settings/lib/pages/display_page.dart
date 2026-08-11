import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/chrome/settings_pill_dropdown.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Display — brightness, auto screen-off, UI scale, and system wallpaper.
class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  double _brightness = 80;
  AutoSleepPolicy _screenOff = AutoSleepPolicy.never;
  bool _loadingScreenOff = true;
  bool _busyBrightness = false;
  int? _queuedBrightness;
  List<WallpaperPreset> _wallpapers = const [];
  String? _appliedWallpaperId;
  bool _loadingWallpaper = true;
  bool _wallpaperBusy = false;
  double _uiScale = 1.0;
  bool _loadingUiScale = true;
  bool _applyingUiScale = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadUiScale());
      unawaited(_loadBrightness());
      unawaited(_loadScreenOff());
      unawaited(_loadWallpaper());
    });
  }

  Future<void> _loadUiScale() async {
    try {
      final services = OsSettingsScope.of(context);
      final scope = OsSettingsScope.maybeOf(context);
      final scale = await services.uiScale().getScale();
      if (!mounted || _applyingUiScale) return;
      setState(() {
        _uiScale = scale;
        _loadingUiScale = false;
      });
      if (scope != null && scope.uiScaleNotifier.value != scale) {
        scope.uiScaleNotifier.value = scale;
      }
    } catch (_) {
      if (mounted && !_applyingUiScale) {
        setState(() => _loadingUiScale = false);
      }
    }
  }

  Future<void> _loadBrightness() async {
    try {
      final v =
          await OsSettingsScope.of(context).backlight().getBrightnessPercent();
      if (mounted) setState(() => _brightness = v.toDouble());
    } catch (_) {}
  }

  Future<void> _loadScreenOff() async {
    try {
      final policy =
          await OsSettingsScope.of(context).autoSleep().getPolicy();
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
      final wallpaper = OsSettingsScope.of(context).wallpaper();
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
      await OsSettingsScope.of(context)
          .backlight()
          .setBrightnessPercent(next);
    } catch (_) {
    } finally {
      _busyBrightness = false;
      if (_queuedBrightness != null) unawaited(_drainBrightness());
    }
  }

  Future<void> _setScreenOff(AutoSleepPolicy policy) async {
    setState(() => _screenOff = policy);
    await OsSettingsScope.of(context).autoSleep().setPolicy(policy);
  }

  Future<void> _setUiScale(double value) async {
    final services = OsSettingsScope.of(context);
    final scope = OsSettingsScope.maybeOf(context);
    _applyingUiScale = true;
    setState(() => _uiScale = value);
    try {
      await services.uiScale().setScale(value);
      scope?.uiScaleNotifier.value = value;
    } catch (e) {
      if (mounted) {
        final scope = OsSettingsScope.maybeOf(context);
        setState(() {
          _uiScale = scope?.uiScaleNotifier.value ?? _uiScale;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      _applyingUiScale = false;
    }
  }

  List<(AutoSleepPolicy, String Function(AppLocalizations))> _screenOffOptions() =>
      [
        (AutoSleepPolicy.minutes10, (l) => l.screenOffOption10Min),
        (AutoSleepPolicy.minutes30, (l) => l.screenOffOption30Min),
        (AutoSleepPolicy.minutes60, (l) => l.screenOffOption60Min),
        (AutoSleepPolicy.never, (l) => l.screenOffNever),
      ];

  Future<void> _applyWallpaper(String presetId) async {
    setState(() => _wallpaperBusy = true);
    try {
      await OsSettingsScope.of(context).wallpaper().setPreset(presetId);
      if (mounted) {
        setState(() => _appliedWallpaperId = presetId);
      }
    } finally {
      if (mounted) {
        setState(() => _wallpaperBusy = false);
      }
    }
  }

  String _screenOffLabel(AppLocalizations l10n) {
    for (final o in _screenOffOptions()) {
      if (o.$1 == _screenOff) return o.$2(l10n);
    }
    return l10n.screenOffNever;
  }

  String _wallpaperLabel(AppLocalizations l10n, String id) {
    for (final p in _wallpapers) {
      if (p.id == id) {
        return p.id == 'home_back' ? l10n.wallpaperOptionDefault : p.label;
      }
    }
    return id;
  }

  List<SettingsWallpaperOption> _wallpaperOptions(AppLocalizations l10n) => [
        for (final p in _wallpapers)
          SettingsWallpaperOption(
            id: p.id,
            label: _wallpaperLabel(l10n, p.id),
            imagePath: p.path,
          ),
      ];


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appliedId =
        _appliedWallpaperId ?? (_wallpapers.isEmpty ? '' : _wallpapers.first.id);

    return SettingsScaffold(
      title: l10n.screenSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              SettingsSliderRow(
                title: l10n.uiScaleText,
                value: '${(_uiScale * 100).round()}%',
                child: CyberSlider(
                  value: _uiScale.clamp(
                    LinuxUiScale.minScale,
                    LinuxUiScale.maxScale,
                  ),
                  min: LinuxUiScale.minScale,
                  max: LinuxUiScale.maxScale,
                  enabled: !_loadingUiScale && !_applyingUiScale,
                  showDragValueLabel: true,
                  dragValueLabelBuilder: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => setState(() => _uiScale = v),
                  onChangeEnd: (v) => unawaited(_setUiScale(v)),
                ),
              ),
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
                  label: _screenOffLabel(l10n),
                  enabled: !_loadingScreenOff,
                  options: [
                    for (final o in _screenOffOptions())
                      SettingsPillOption(
                        value: o.$1,
                        label: o.$2(l10n),
                      ),
                  ],
                  onChanged: (v) => unawaited(_setScreenOff(v)),
                ),
              ),
            ],
          ),
          SettingsHelpFooter(l10n.uiScaleHelp),
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
            SettingsHelpFooter(l10n.wallpaperSectionHelp),
          ],
        ],
      ),
    );
  }
}
