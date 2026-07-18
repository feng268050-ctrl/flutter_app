import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cyber_hal/datetime.dart';

/// P2.2 Demo: date / time / timezone + Manual vs Network sync.
class DateTimeDemoSection extends StatefulWidget {
  const DateTimeDemoSection({super.key, required this.controller});

  final DateTimeController controller;

  @override
  State<DateTimeDemoSection> createState() => _DateTimeDemoSectionState();
}

class _DateTimeDemoSectionState extends State<DateTimeDemoSection> {
  final _date = TextEditingController();
  final _time = TextEditingController();
  Timer? _tick;
  TimeSyncMode _mode = TimeSyncMode.network;
  String _timezone = 'Asia/Shanghai';
  String _live = '';
  String _status = '';
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final mode = await widget.controller.getSyncMode();
      final tz = await widget.controller.getTimezone();
      final now = await widget.controller.now();
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = mode;
        _timezone = TimeSyncPrefs.curatedTimezones.contains(tz)
            ? tz
            : (tz.isEmpty ? 'Asia/Shanghai' : tz);
        if (!TimeSyncPrefs.curatedTimezones.contains(_timezone)) {
          // Keep custom zone visible by falling back display to Asia/Shanghai
          // but still show live clock; preference retained on Apply timezone.
          _timezone = 'Asia/Shanghai';
        }
        _date.text =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        _time.text =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
        _live = now.toString();
        _ready = true;
      });
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_refreshLive());
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'load: $e';
          _ready = true;
        });
      }
    }
  }

  Future<void> _refreshLive() async {
    try {
      final now = await widget.controller.now();
      if (mounted) {
        setState(() => _live = now.toString());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  Future<void> _applyManual() async {
    setState(() {
      _busy = true;
      _status = 'applying…';
    });
    try {
      final d = _date.text.trim().split('-');
      final t = _time.text.trim().split(':');
      if (d.length != 3 || t.length < 2) {
        throw FormatException('use YYYY-MM-DD and HH:MM[:SS]');
      }
      final local = DateTime(
        int.parse(d[0]),
        int.parse(d[1]),
        int.parse(d[2]),
        int.parse(t[0]),
        int.parse(t[1]),
        t.length > 2 ? int.parse(t[2]) : 0,
      );
      await widget.controller.setTimezone(_timezone);
      await widget.controller.setWallClock(local);
      final mode = await widget.controller.getSyncMode();
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = mode;
        _status = 'manual set OK → mode=${TimeSyncPrefs.modeToToken(mode)}';
      });
      await _refreshLive();
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'apply: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _status = 'syncing…';
    });
    try {
      final r = await widget.controller.syncFromNetwork();
      if (!mounted) {
        return;
      }
      setState(() => _status = r.ok ? 'sync OK: ${r.message}' : 'sync fail: ${r.message}');
      await _refreshLive();
      final now = await widget.controller.now();
      if (mounted) {
        setState(() {
          _date.text =
              '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';
          _time.text =
              '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}:'
              '${now.second.toString().padLeft(2, '0')}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'sync: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setMode(TimeSyncMode mode) async {
    setState(() => _busy = true);
    try {
      await widget.controller.setSyncMode(mode);
      if (mounted) {
        setState(() {
          _mode = mode;
          _status = 'mode → ${TimeSyncPrefs.modeToToken(mode)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'mode: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date & Time',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Now: $_live',
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 12),
        const Text('Sync mode', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        SegmentedButton<TimeSyncMode>(
          segments: const [
            ButtonSegment(value: TimeSyncMode.manual, label: Text('Manual')),
            ButtonSegment(value: TimeSyncMode.network, label: Text('Network')),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (set) {
                  if (set.isEmpty) {
                    return;
                  }
                  unawaited(_setMode(set.first));
                },
        ),
        const SizedBox(height: 12),
        const Text('Timezone', style: TextStyle(color: Colors.white70)),
        DropdownButton<String>(
          value: _timezone,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          items: [
            for (final z in TimeSyncPrefs.curatedTimezones)
              DropdownMenuItem(value: z, child: Text(z)),
          ],
          onChanged: _busy
              ? null
              : (v) {
                  if (v != null) {
                    setState(() => _timezone = v);
                  }
                },
        ),
        _field(_date, 'Date (YYYY-MM-DD)'),
        _field(_time, 'Time (HH:MM:SS)'),
        Row(
          children: [
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_applyManual()),
              child: const Text('Apply'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _busy ? null : () => unawaited(_syncNow()),
              child: const Text('Sync Now'),
            ),
          ],
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _status,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        enabled: !_busy,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white38),
          ),
        ),
      ),
    );
  }
}
