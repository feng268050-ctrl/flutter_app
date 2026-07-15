import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/platform/ssh/ssh_debug_controller.dart';

/// P2.1 Demo: on-demand LAN/WLAN SSH debug toggle.
class SshDebugDemoSection extends StatefulWidget {
  const SshDebugDemoSection({super.key, required this.controller});

  final SshDebugController controller;

  @override
  State<SshDebugDemoSection> createState() => _SshDebugDemoSectionState();
}

class _SshDebugDemoSectionState extends State<SshDebugDemoSection> {
  bool _enabled = false;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final on = await widget.controller.isEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = on;
        _status = on ? 'LAN SSH debug on' : 'LAN SSH debug off';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'status: $e');
      }
    }
  }

  Future<void> _onChanged(bool value) async {
    setState(() {
      _busy = true;
      _status = value ? 'enabling…' : 'disabling…';
    });
    try {
      await widget.controller.setEnabled(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = value;
        _status = value
            ? 'LAN SSH debug on (root / rockchip; make connect <ip>)'
            : 'LAN SSH debug off';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'toggle: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LAN SSH debug',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'On-demand sshd on eth0 / wlan0 only (USB-SSH on 192.168.55.1 stays up). '
          'Use make connect <ip> on the host after enabling.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable LAN SSH',
            style: TextStyle(color: Colors.white),
          ),
          value: _enabled,
          onChanged: _busy ? null : (v) => unawaited(_onChanged(v)),
        ),
        SelectableText(
          _status.isEmpty ? '(checking…)' : _status,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
