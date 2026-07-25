import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:flutter/material.dart';

/// P2.1 Demo: USB HID keyboard + XKB layout (US ↔ RU).
///
/// Layout apply restarts `hmi.service`; App must restore route after relaunch.
class KeyboardDemoSection extends StatefulWidget {
  const KeyboardDemoSection({
    super.key,
    this.probe = const UsbHidKeyboardProbe(),
    this.keyboard,
  });

  final UsbHidKeyboardProbe probe;
  final Keyboard? keyboard;

  @override
  State<KeyboardDemoSection> createState() => _KeyboardDemoSectionState();
}

class _KeyboardDemoSectionState extends State<KeyboardDemoSection>
    with AutomaticKeepAliveClientMixin {
  String _presence = '…';
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _poll;
  late final Keyboard _keyboard;
  late final bool _ownsKeyboard;
  KeyboardLayout? _layout;
  List<KeyboardLayout> _layouts = const <KeyboardLayout>[];
  bool _layoutBusy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ownsKeyboard = widget.keyboard == null;
    _keyboard = widget.keyboard ?? LinuxKeyboard();
    unawaited(_refreshPresence());
    unawaited(_loadLayouts());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Future<void> _refreshPresence() async {
    final line = await widget.probe.statusLine();
    if (!mounted) {
      return;
    }
    setState(() => _presence = line ?? 'probe unavailable');
  }

  Future<void> _loadLayouts() async {
    try {
      final layouts = await _keyboard.listLayouts();
      final current = await _keyboard.getLayout();
      if (!mounted) {
        return;
      }
      setState(() {
        _layouts = layouts;
        _layout = current;
      });
    } catch (e) {
      debugPrint('keyboard demo: load layout failed: $e');
    }
  }

  Future<void> _selectLayout(KeyboardLayout layout) async {
    if (_layoutBusy) {
      return;
    }
    setState(() {
      _layoutBusy = true;
      _layout = layout;
    });
    try {
      await _keyboard.setLayout(layout);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Layout → ${layout.displayName ?? layout.id}. '
            'On device, HMI restarts; restore this page after relaunch.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('keyboard demo: set layout failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Layout change failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _layoutBusy = false);
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    if (_ownsKeyboard) {
      unawaited(_keyboard.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Keyboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'USB or Bluetooth HID. '
          '1 mm USB host / Micro-USB when Debug over USB is OFF '
          '(OTG adapter). Debug over USB ON = plug-ssh. Not soft IME (P4). '
          'Layout apply restarts HMI (App restores route after relaunch).',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          _presence,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (_layouts.isNotEmpty) ...[
          Text(
            'Layout',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layout in _layouts)
                ChoiceChip(
                  label: Text(layout.displayName ?? layout.id),
                  selected: _layout?.id == layout.id,
                  onSelected: _layoutBusy
                      ? null
                      : (selected) {
                          if (selected) {
                            unawaited(_selectLayout(layout));
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _text,
          focusNode: _focus,
          decoration: const InputDecoration(
            labelText: 'Type here to verify keys',
            border: OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              _focus.requestFocus();
              unawaited(_refreshPresence());
              unawaited(_loadLayouts());
            },
            child: const Text('Focus + refresh'),
          ),
        ),
      ],
    );
  }
}
