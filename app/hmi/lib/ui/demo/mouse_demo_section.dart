import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/input/linux_mouse_settings.dart';
import 'package:lws_hmi/platform/input/mouse_settings.dart';
import 'package:lws_hmi/platform/input/usb_hid_mouse_probe.dart';

/// P2.1 Demo: USB HID mouse presence, pointer smoke note, OS mouse settings.
class MouseDemoSection extends StatefulWidget {
  const MouseDemoSection({
    super.key,
    this.probe = const UsbHidMouseProbe(),
    this.controller,
  });

  final UsbHidMouseProbe probe;
  final MouseSettingsController? controller;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'USB mouse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'HID via 1 mm USB host, or Micro-USB when Debug over USB is OFF. '
          'Pointer should be visible when a mouse is attached. '
          'Settings persist under /var/lib/lws-hmi/mouse.conf.',
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
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Natural scrolling', style: TextStyle(color: Colors.white)),
            value: _settings.naturalScroll,
            onChanged: (v) => unawaited(
              _apply(_settings.copyWith(naturalScroll: v)),
            ),
          ),
          Text('Scroll speed', style: muted),
          Slider(
            value: _settings.scrollSpeedPercent.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_settings.scrollSpeedPercent}%',
            onChanged: (v) => setState(
              () => _settings = _settings.copyWith(scrollSpeedPercent: v.round()),
            ),
            onChangeEnd: (v) => unawaited(
              _apply(_settings.copyWith(scrollSpeedPercent: v.round())),
            ),
          ),
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
      ],
    );
  }
}
