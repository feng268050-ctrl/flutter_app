import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_hal/input.dart';
import 'package:flutter/material.dart';

/// P2.1 Demo: USB HID mouse presence, pointer smoke note, OS mouse settings.
class MouseDemoSection extends StatefulWidget {
  const MouseDemoSection({
    super.key,
    this.probe = const UsbHidMouseProbe(),
    this.controller,
    this.displayStack = DisplayStack.unknown,
  });

  final UsbHidMouseProbe probe;
  final MouseSettingsController? controller;
  final DisplayStack displayStack;

  @override
  State<MouseDemoSection> createState() => _MouseDemoSectionState();
}

class _MouseDemoSectionState extends State<MouseDemoSection>
    with AutomaticKeepAliveClientMixin {
  late final MouseSettingsController _controller;
  late final bool _ownsController;
  String _presence = '…';
  MouseSettings _settings = MouseSettings.defaults();
  bool _loading = true;
  Timer? _poll;

  MouseSettingAvailability get _avail => widget.displayStack.mouseSettings;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? LinuxMouseSettingsController();
    unawaited(_bootstrap());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Future<void> _bootstrap() async {
    await Future.wait([_refreshPresence(), _loadSettings()]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshPresence() async {
    final line = await widget.probe.statusLine();
    if (!mounted) {
      return;
    }
    setState(() => _presence = line);
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _controller.getSettings();
      if (!mounted) {
        return;
      }
      setState(() => _settings = s);
    } catch (e) {
      debugPrint('mouse demo: load failed: $e');
    }
  }

  Future<void> _apply(MouseSettings next) async {
    setState(() => _settings = next);
    try {
      await _controller.setSettings(next);
    } catch (e) {
      debugPrint('mouse demo: apply failed: $e');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final muted = TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14);
    final avail = _avail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mouse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'USB or Bluetooth HID pointer. '
          'Pointer should be visible when a mouse or keyboard trackpad is attached. '
          'Settings persist under /var/lib/hal/mouse.conf.',
          style: muted,
        ),
        const SizedBox(height: 8),
        Text(
          _presence,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ] else ...[
          if (avail.naturalScroll) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Natural scrolling',
                style: TextStyle(color: Colors.white),
              ),
              value: _settings.naturalScroll,
              onChanged: (v) => unawaited(
                _apply(_settings.copyWith(naturalScroll: v)),
              ),
            ),
          ],
          if (avail.scrollSpeed) ...[
            Text('Scroll speed', style: muted),
            Slider(
              value: _settings.scrollSpeedPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_settings.scrollSpeedPercent}%',
              onChanged: (v) => setState(
                () => _settings =
                    _settings.copyWith(scrollSpeedPercent: v.round()),
              ),
              onChangeEnd: (v) => unawaited(
                _apply(_settings.copyWith(scrollSpeedPercent: v.round())),
              ),
            ),
          ],
          if (avail.pointerSpeed) ...[
            Text('Pointer speed', style: muted),
            Slider(
              value: _settings.pointerSpeedPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_settings.pointerSpeedPercent}%',
              onChanged: (v) => setState(
                () => _settings =
                    _settings.copyWith(pointerSpeedPercent: v.round()),
              ),
              onChangeEnd: (v) => unawaited(
                _apply(_settings.copyWith(pointerSpeedPercent: v.round())),
              ),
            ),
          ],
          if (avail.pointerSize) ...[
            Text('Pointer size', style: muted),
            Slider(
              value: _settings.pointerSizePercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_settings.pointerSizePercent}%',
              onChanged: (v) => setState(
                () => _settings =
                    _settings.copyWith(pointerSizePercent: v.round()),
              ),
              onChangeEnd: (v) => unawaited(
                _apply(_settings.copyWith(pointerSizePercent: v.round())),
              ),
            ),
          ],
          if (avail.primaryButton) ...[
            const SizedBox(height: 4),
            Text('Primary button', style: muted),
            const SizedBox(height: 4),
            SegmentedButton<MousePrimaryButton>(
              segments: const [
                ButtonSegment(
                  value: MousePrimaryButton.left,
                  label: Text('Left'),
                ),
                ButtonSegment(
                  value: MousePrimaryButton.right,
                  label: Text('Right'),
                ),
              ],
              selected: {_settings.primaryButton},
              onSelectionChanged: (set) {
                if (set.isEmpty) {
                  return;
                }
                unawaited(_apply(_settings.copyWith(primaryButton: set.first)));
              },
            ),
          ],
          if (avail.pointerAxes) ...[
            const SizedBox(height: 12),
            Text('Pointer axes', style: muted),
            const SizedBox(height: 4),
            Text(
              'Auto = Raw (native axes). Use Swap XY only if left/right moves '
              'the pointer up/down. Takes effect within ~1s.',
              style: muted.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            SegmentedButton<MousePointerAxes>(
              segments: const [
                ButtonSegment(
                  value: MousePointerAxes.auto,
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: MousePointerAxes.normal,
                  label: Text('Raw'),
                ),
                ButtonSegment(
                  value: MousePointerAxes.swap,
                  label: Text('Swap XY'),
                ),
              ],
              selected: {_settings.pointerAxes},
              onSelectionChanged: (set) {
                if (set.isEmpty) {
                  return;
                }
                unawaited(_apply(_settings.copyWith(pointerAxes: set.first)));
              },
            ),
          ],
        ],
      ],
    );
  }
}
