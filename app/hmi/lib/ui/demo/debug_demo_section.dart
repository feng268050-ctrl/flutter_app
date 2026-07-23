import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cyber_hal/debug.dart';

/// P2 Demo: Debug group — USB Debug (persisted) + LAN Debug (session only).
class DebugDemoSection extends StatefulWidget {
  const DebugDemoSection({
    super.key,
    required this.usbDebug,
    required this.lanDebug,
  });

  final UsbDebugController usbDebug;
  final SshDebugController lanDebug;

  @override
  State<DebugDemoSection> createState() => _DebugDemoSectionState();
}

class _DebugDemoSectionState extends State<DebugDemoSection> {
  bool _usbOn = true;
  bool _lanOn = false;
  bool _usbBusy = false;
  bool _lanBusy = false;
  String _usbStatus = '';
  String _lanStatus = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final usb = await widget.usbDebug.isEnabled();
      final lan = await widget.lanDebug.isEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _usbOn = usb;
        _lanOn = lan;
        _usbStatus = usb
            ? 'Debug over USB on — Micro-USB = plug-ssh (PC cable)'
            : 'Debug over USB off — Micro-USB = host (keyboard / OTG adapter)';
        _lanStatus = lan ? 'Debug over LAN on' : 'Debug over LAN off';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _usbStatus = 'USB status: $e';
          _lanStatus = 'LAN status: $e';
        });
      }
    }
  }

  Future<void> _onUsb(bool value) async {
    setState(() {
      _usbBusy = true;
      _usbStatus = value ? 'enabling Debug over USB…' : 'switching to USB host…';
    });
    try {
      await widget.usbDebug.setEnabled(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _usbOn = value;
        _usbStatus = value
            ? 'Debug over USB on — Micro-USB = plug-ssh (PC cable)'
            : 'Debug over USB off — Micro-USB = host (keyboard / OTG adapter)';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _usbStatus = 'Debug over USB: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _usbBusy = false);
      }
    }
  }

  Future<void> _onLan(bool value) async {
    setState(() {
      _lanBusy = true;
      _lanStatus = value ? 'enabling…' : 'disabling…';
    });
    try {
      await widget.lanDebug.setEnabled(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _lanOn = value;
        _lanStatus = value
            ? 'Debug over LAN on (root / rockchip; make connect <ip>)'
            : 'Debug over LAN off (not persisted across reboot)';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _lanStatus = 'Debug over LAN: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _lanBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14);
    final mono = TextStyle(
      color: Colors.white.withOpacity(0.85),
      fontSize: 14,
      fontFamily: 'monospace',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Micro-USB ID is not used for auto role switch. '
          'Debug over USB ON (default, saved): PC cable → USB-SSH. '
          'OFF: OTG adapter → keyboard. '
          'Debug over LAN is session-only and defaults off.',
          style: hint,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Debug over USB',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Persisted under /var/lib/hal/usb-debug',
            style: hint,
          ),
          value: _usbOn,
          onChanged: _usbBusy ? null : (v) => unawaited(_onUsb(v)),
        ),
        SelectableText(
          _usbStatus.isEmpty ? '(checking…)' : _usbStatus,
          style: mono,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Debug over LAN',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'sshd on LAN / WLAN ifaces; not restored after reboot',
            style: hint,
          ),
          value: _lanOn,
          onChanged: _lanBusy ? null : (v) => unawaited(_onLan(v)),
        ),
        SelectableText(
          _lanStatus.isEmpty ? '(checking…)' : _lanStatus,
          style: mono,
        ),
      ],
    );
  }
}
