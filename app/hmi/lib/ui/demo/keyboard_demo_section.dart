import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/input/usb_hid_keyboard_probe.dart';

/// P2.1 Demo: USB HID keyboard on 1 mm host expansion (not Micro-USB OTG).
class KeyboardDemoSection extends StatefulWidget {
  const KeyboardDemoSection({
    super.key,
    this.probe = const UsbHidKeyboardProbe(),
  });

  final UsbHidKeyboardProbe probe;

  @override
  State<KeyboardDemoSection> createState() => _KeyboardDemoSectionState();
}

class _KeyboardDemoSectionState extends State<KeyboardDemoSection>
    with AutomaticKeepAliveClientMixin {
  String _presence = '…';
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _poll;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPresence());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Future<void> _refreshPresence() async {
    final line = await widget.probe.statusLine();
    if (!mounted) {
      return;
    }
    setState(() => _presence = line);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'USB keyboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '1 mm pin → USB host expansion (HID). '
          'Micro-USB OTG stays plug-ssh. Not soft IME (P4).',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          _presence,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        ),
        const SizedBox(height: 12),
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
            },
            child: const Text('Focus + refresh'),
          ),
        ),
      ],
    );
  }
}
