import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/debug.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/linux_bluez_bluetooth_controller.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/linux_http_client_controller.dart';
import 'package:lws_hmi/ui/demo/bluetooth_demo_section.dart';
import 'package:lws_hmi/ui/demo/date_time_demo_section.dart';
import 'package:lws_hmi/ui/demo/debug_demo_section.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';
import 'package:lws_hmi/ui/demo/ethernet_demo_section.dart';
import 'package:lws_hmi/ui/demo/http_demo_section.dart';
import 'package:lws_hmi/ui/demo/keyboard_demo_section.dart';
import 'package:lws_hmi/ui/demo/mouse_demo_section.dart';
import 'package:lws_hmi/ui/demo/wifi_demo_section.dart';

/// P2 demo: device info, alarms, and Debug smoke.
///
/// Platform settings (network, input, date/time, audio, backlight, RGB LED)
/// live under product Settings. Pass [skipPlatformSections] when hosted on `/demo`.
class P2DemoPage extends StatefulWidget {
  const P2DemoPage({
    super.key,
    this.boardProfile,
    this.deviceSnReader = const DeviceSnReader(),
    this.sysInfo,
    this.modbusClient,
    this.audioController,
    this.backlightController,
    this.ethernetController,
    this.wifiController,
    this.httpClientController,
    this.dateTimeController,
    this.sshDebugController,
    this.usbDebugController,
    this.bluetoothController,
    this.skipPlatformSections = true,
    this.skipSettingsRestore = false,
  });

  /// Live board wiring (D22). When null, Demo falls back to package defaults.
  final BoardProfile? boardProfile;

  final DeviceSnReader deviceSnReader;

  /// Host inventory (`package:cyber_hal/sys_info`). Defaults via [BoardBindings].
  final SysInfo? sysInfo;
  final ModbusRtuClient? modbusClient;
  final MediaAudioController? audioController;
  final BacklightController? backlightController;
  final EthernetController? ethernetController;
  final WifiController? wifiController;
  final HttpClientController? httpClientController;
  final DateTimeController? dateTimeController;
  final SshDebugController? sshDebugController;
  final UsbDebugController? usbDebugController;
  final BluetoothController? bluetoothController;

  /// When true (default), omit Settings-owned sections; keep Debug.
  final bool skipPlatformSections;

  /// When true, skip HAL restore (app already restored via [AppServices]).
  final bool skipSettingsRestore;

  @override
  State<P2DemoPage> createState() => _P2DemoPageState();
}

class _P2DemoPageState extends State<P2DemoPage> {
  late final SysInfo _sysInfo;
  late final ModbusRtuClient _modbus;
  late final MediaAudioController _audio;
  late final BacklightController _backlight;
  late final EthernetController _ethernet;
  late final WifiController _wifi;
  late final DateTimeController _dateTime;
  late final HttpClientController _http;
  late final SshDebugController _sshDebug;
  late final UsbDebugController _usbDebug;
  late final BluetoothController _bluetooth;
  late final Keyboard _keyboard;
  late final MouseSettingsController _mouse;
  DisplayStack _displayStack = DisplayStack.unknown;
  bool _networkSectionsReady = false;

  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _controlCardVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;
  String _kernelVersion = kUnavailableDisplay;
  String _systemVersion = kUnavailableDisplay;

  String _pumpCommStatus = kUnavailableDisplay;
  String _gunCommAlarm = kUnavailableDisplay;
  String _feederCommStatus = kUnavailableDisplay;
  String _modbusLink = kUnavailableDisplay;

  bool _audioPlaying = false;
  double _volumePercent = 80;
  double _brightnessPercent = 80;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<SysInfoUpdate>? _sysInfoSub;
  StreamSubscription<List<ModbusAttributeChange>>? _modbusAttrSub;
  StreamSubscription<ModbusHealth>? _modbusHealthSub;
  BoardBindings? _bindings;

  // Brightness: latest-wins coalesce (same idea as AudioManager / backlight HAL).
  bool _brightnessBusy = false;
  int? _queuedBrightness;
  bool _listScrolling = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.boardProfile;
    final bindings = profile != null ? BoardBindings(profile) : null;
    _bindings = bindings;
    _sysInfo = widget.sysInfo ??
        (bindings?.sysInfo(
              deviceSnReader: widget.deviceSnReader,
              appVersion: kSystemVersion,
            ) ??
            LinuxSysInfo(
              deviceSnReader: widget.deviceSnReader,
              appVersion: kSystemVersion,
            ));
    _modbus = widget.modbusClient ??
        ModbusRtuClient(
          profile: profile,
          halFuture: bindings?.modbus(),
        );
    _audio = widget.audioController ??
        bindings?.mediaAudio() ??
        LinuxMediaAudioController();
    _backlight = widget.backlightController ??
        bindings?.backlight() ??
        LinuxSysfsBacklight();
    _ethernet = widget.ethernetController ??
        bindings?.ethernetSession() ??
        LinuxEthernetSession();
    _wifi = widget.wifiController ??
        bindings?.wifiSession() ??
        LinuxWifiSession();
    _dateTime = widget.dateTimeController ??
        bindings?.dateTime() ??
        LinuxDateTimeController();
    _http = widget.httpClientController ??
        LinuxHttpClientController(dateTimeController: _dateTime);
    _sshDebug = widget.sshDebugController ??
        bindings?.sshDebug() ??
        LinuxSshDebugController();
    _usbDebug = widget.usbDebugController ??
        bindings?.usbDebug() ??
        LinuxUsbDebugController();
    _bluetooth = widget.bluetoothController ??
        bindings?.bluetooth() ??
        LinuxBluezBluetoothController();
    _keyboard = bindings?.keyboard() ?? LinuxKeyboard();
    _mouse = bindings?.mouse() ?? LinuxMouseSettingsController();
    _playingSub = _audio.playing.listen((playing) {
      if (!mounted) {
        return;
      }
      setState(() => _audioPlaying = playing);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAfterFirstFrame());
    });
  }

  Future<void> _loadAfterFirstFrame() async {
    // Mount network sections ASAP after first frame (do not wait for Modbus).
    if (mounted) {
      setState(() => _networkSectionsReady = true);
    }

    final app = AppScope.maybeOf(context);
    if (app != null) {
      _displayStack = await app.ensureDisplayStack();
    } else {
      final bindings = _bindings;
      if (bindings != null) {
        try {
          _displayStack = await bindings.displayStack();
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {});
    }

    try {
      _sysInfoSub = _sysInfo
          .watch(interval: const Duration(seconds: 1))
          .listen(_onSysInfoUpdate, onError: (_) {});
    } catch (_) {
      // Soft-fail: tiles stay at `-`.
    }

    // Prefer app-scoped Modbus fan-out when under AppScope (Home owns live start).
    if (app != null) {
      try {
        await app.ensureModbusLive();
        _modbusAttrSub =
            app.modbusAttributeChanges.listen(_onModbusAttributeChanges);
        _modbusHealthSub = app.modbusHealthChanges.listen(_onModbusHealth);
      } catch (_) {}
    } else {
      try {
        await _modbus.startLiveDemo(
          onAttributeChanges: _onModbusAttributeChanges,
          onHealth: _onModbusHealth,
        );
      } catch (_) {
        // Soft-fail: tiles stay at `-`.
      }
    }

    // HAL-owned settings restore (skipped when AppServices already restored).
    if (widget.skipSettingsRestore) {
      return;
    }
    try {
      final b = _bindings;
      if (b != null) {
        final bl = _backlight;
        final audio = _audio;
        final mouse = _mouse;
        final wifi = _wifi;
        final eth = _ethernet;
        final bt = _bluetooth;
        final dt = _dateTime;
        await b.restorePersistedSettings(
          backlight: bl is LinuxSysfsBacklight ? bl : null,
          mediaAudio: audio is LinuxMediaAudioController ? audio : null,
          mouse: mouse is LinuxMouseSettingsController ? mouse : null,
          wifi: wifi is LinuxWifiSession ? wifi : null,
          ethernet: eth is LinuxEthernetSession ? eth : null,
          bluetooth: bt is LinuxBluezBluetoothController ? bt : null,
          dateTime: dt is LinuxDateTimeController ? dt : null,
        );
      } else if (_backlight is LinuxSysfsBacklight) {
        await _backlight.applyPersistedPreference();
      }
      if (widget.skipPlatformSections) {
        return;
      }
      final vol = await _audio.getVolumePercent();
      final bri = await _backlight.getBrightnessPercent();
      if (!mounted) {
        return;
      }
      setState(() {
        _volumePercent = vol.toDouble();
        _brightnessPercent = bri.toDouble();
      });
    } catch (_) {
      // Non-fatal: sliders keep defaults.
    }
  }

  void _onSysInfoUpdate(SysInfoUpdate update) {
    if (!mounted) {
      return;
    }
    final snap = update.snapshot;
    setState(() {
      _deviceSn = snap.serialNumber ?? kUnavailableDisplay;
      _kernelVersion = snap.kernelRelease ?? kUnavailableDisplay;
      _systemVersion = snap.appVersion ?? kUnavailableDisplay;
    });
  }

  void _onModbusHealth(ModbusHealth health) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (!health.ok || health.truncated) {
        _modbusLink = 'FAULT';
      } else if (health.groupId == null) {
        // Aggregate window healthy.
        _modbusLink = 'OK';
      } else if (_modbusLink == kUnavailableDisplay) {
        _modbusLink = 'OK';
      }
    });
  }

  void _onModbusAttributeChanges(List<ModbusAttributeChange> changes) {
    if (!mounted || changes.isEmpty) {
      return;
    }
    setState(() {
      for (final c in changes) {
        switch (c.id) {
          case 'device.control_card_version':
            _controlCardVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.laser_sw_version':
            _laserVersion =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
          case 'device.wire_feeder_sw_version':
            _wireFeederVersion =
                modbusDisplayOrDash(modbusControlCardDisplay(c.value));
          case 'device.gun_head_sn':
            _gunheadSn =
                modbusDisplayOrDash(modbusVersionStringDisplay(c.value));
          case 'alarm.laser_comm':
            _pumpCommStatus = _alarmDisplay(c);
          case 'alarm.gun_comm':
            _gunCommAlarm = _alarmDisplay(c);
          case 'alarm.wire_feeder_comm':
            _feederCommStatus = _alarmDisplay(c);
        }
      }
    });
  }

  String _alarmDisplay(ModbusAttributeChange c) {
    final base = modbusAlarmBoolDisplay(c.value);
    if (c.isReminder && base == 'ALARM') {
      return 'ALARM (remind)';
    }
    return base;
  }

  Future<void> _toggleAudio() async {
    if (_audio.isPlaying || _audioPlaying) {
      await _audio.stop();
      return;
    }
    await _audio.playAsset(MediaAudioController.shanghaiTanAsset);
  }

  /// Slider paint is local only; hardware apply runs on [onChangeEnd] (OS-style).
  void _onVolumeUi(double value) {
    _volumePercent = value;
  }

  void _onBrightnessUi(double value) {
    _brightnessPercent = value;
  }

  Future<void> _drainBrightness() async {
    if (_brightnessBusy) {
      return;
    }
    _brightnessBusy = true;
    try {
      while (_queuedBrightness != null) {
        final v = _queuedBrightness!;
        _queuedBrightness = null;
        await _backlight.setBrightnessPercent(v);
      }
    } finally {
      _brightnessBusy = false;
      if (_queuedBrightness != null) {
        unawaited(_drainBrightness());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_sysInfoSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusAttrSub?.cancel() ?? Future<void>.value());
    unawaited(_modbusHealthSub?.cancel() ?? Future<void>.value());
    unawaited(_sysInfo.close());
    unawaited(_playingSub?.cancel() ?? Future<void>.value());
    final bri = _queuedBrightness;
    if (bri != null) {
      unawaited(_backlight.setBrightnessPercent(bri));
    }
    unawaited(_audio.dispose());
    unawaited(_backlight.dispose());
    unawaited(_ethernet.dispose());
    unawaited(_wifi.dispose());
    unawaited(_dateTime.dispose());
    unawaited(_http.dispose());
    unawaited(_bluetooth.dispose());
    unawaited(_modbus.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: DemoScrollInteraction(
          scrolling: _listScrolling,
          child: Listener(
            onPointerMove: (event) {
              // Claim "scrolling" before Switch wins a vertical drag that started on it.
              if (event.delta.dy.abs() > 1.5 && !_listScrolling) {
                setState(() => _listScrolling = true);
              }
            },
            onPointerUp: (_) {
              if (_listScrolling) {
                setState(() => _listScrolling = false);
              }
            },
            onPointerCancel: (_) {
              if (_listScrolling) {
                setState(() => _listScrolling = false);
              }
            },
            child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) {
                return false;
              }
              if (notification is ScrollStartNotification ||
                  notification is ScrollUpdateNotification) {
                if (!_listScrolling) {
                  setState(() => _listScrolling = true);
                }
              } else if (notification is ScrollEndNotification) {
                if (_listScrolling) {
                  setState(() => _listScrolling = false);
                }
              }
              return false;
            },
            child: ListView(
              // Keep enough off-screen children built for Demo tiles / widget tests.
              cacheExtent: 4000,
              padding: const EdgeInsets.all(24),
              children: [
            const Text(
              'Device Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _InfoTile(label: 'Device SN', value: _deviceSn),
            _InfoTile(label: 'Gunhead SN', value: _gunheadSn),
            _InfoTile(label: 'System Version', value: _systemVersion),
            _InfoTile(label: 'Kernel Version', value: _kernelVersion),
            _InfoTile(
              label: 'Control Card Version',
              value: _controlCardVersion,
            ),
            _InfoTile(label: 'Laser Version', value: _laserVersion),
            _InfoTile(label: 'Wire Feeder Version', value: _wireFeederVersion),
            _InfoTile(label: 'Modbus Link', value: _modbusLink),
            const SizedBox(height: 32),
            const Text(
              'Alarm Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _InfoTile(label: 'Pump Comm Status', value: _pumpCommStatus),
            _InfoTile(label: 'Gun Comm Status', value: _gunCommAlarm),
            _InfoTile(label: 'Feeder Comm Status', value: _feederCommStatus),
            if (!widget.skipPlatformSections) ...[
              const SizedBox(height: 24),
              const Text(
                'Speaker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track: shanghai_tan.mp3 (ALSA / mpg123)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => unawaited(_toggleAudio()),
                  child: Text(_audioPlaying ? 'Stop' : 'Play'),
                ),
              ),
              const SizedBox(height: 8),
              _PercentSlider(
                label: 'Volume',
                value: _volumePercent,
                onChanged: _onVolumeUi,
                onChangeEnd: (v) {
                  _volumePercent = v;
                  unawaited(_audio.setVolumePercent(v.round()));
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Backlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _PercentSlider(
                label: 'Brightness',
                value: _brightnessPercent,
                onChanged: _onBrightnessUi,
                onChangeEnd: (v) {
                  _brightnessPercent = v;
                  _queuedBrightness = v.round();
                  unawaited(_drainBrightness());
                },
              ),
              if (_networkSectionsReady) ...[
                const SizedBox(height: 32),
                KeyboardDemoSection(keyboard: _keyboard),
                const SizedBox(height: 32),
                MouseDemoSection(
                  controller: _mouse,
                  displayStack: _displayStack,
                ),
                const SizedBox(height: 32),
                DateTimeDemoSection(controller: _dateTime),
                const SizedBox(height: 32),
                EthernetDemoSection(controller: _ethernet),
                const SizedBox(height: 32),
                WifiDemoSection(controller: _wifi),
                const SizedBox(height: 32),
                HttpDemoSection(controller: _http),
                const SizedBox(height: 32),
                BluetoothDemoSection(controller: _bluetooth),
              ],
            ],
            if (_networkSectionsReady) ...[
              const SizedBox(height: 32),
              DebugDemoSection(usbDebug: _usbDebug, lanDebug: _sshDebug),
            ],
            const SizedBox(height: 24),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 16,
        ),
      ),
    );
  }
}

class _PercentSlider extends StatefulWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
  });

  final String label;
  final double value;
  final double min;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {
  late double _value;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(widget.min, 100);
  }

  @override
  void didUpdateWidget(covariant _PercentSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from parent (e.g. post-frame hardware read) only when not dragging.
    if (!_dragging && (oldWidget.value - widget.value).abs() > 0.01) {
      _value = widget.value.clamp(widget.min, 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.label}: ${_value.round()}%',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        Slider(
          value: _value,
          min: widget.min,
          max: 100,
          // Continuous (no divisions) → fewer rebuild snaps while dragging.
          onChanged: (v) {
            _dragging = true;
            setState(() => _value = v);
            widget.onChanged(v);
          },
          onChangeEnd: (v) {
            _dragging = false;
            setState(() => _value = v);
            widget.onChangeEnd?.call(v);
          },
        ),
      ],
    );
  }
}
