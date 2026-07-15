import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/device/device_sn_reader.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/gpio/gpio_led_config.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/platform/audio/linux_media_audio_controller.dart';
import 'package:lws_hmi/platform/audio/media_audio_controller.dart';
import 'package:lws_hmi/platform/backlight/backlight_controller.dart';
import 'package:lws_hmi/platform/backlight/linux_sysfs_backlight.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_controller.dart';
import 'package:lws_hmi/platform/bluetooth/linux_bluez_bluetooth_controller.dart';
import 'package:lws_hmi/platform/display/display_orientation.dart';
import 'package:lws_hmi/platform/display/linux_flutter_pi_orientation.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_controller.dart';
import 'package:lws_hmi/platform/ethernet/linux_ethernet_controller.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/linux_http_client_controller.dart';
import 'package:lws_hmi/platform/wifi/linux_wpa_wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/ui/demo/bluetooth_demo_section.dart';
import 'package:lws_hmi/ui/demo/demo_scroll_interaction.dart';
import 'package:lws_hmi/ui/demo/ethernet_demo_section.dart';
import 'package:lws_hmi/ui/demo/http_demo_section.dart';
import 'package:lws_hmi/ui/demo/keyboard_demo_section.dart';
import 'package:lws_hmi/ui/demo/wifi_demo_section.dart';

/// P2 / P2.1 demo: device info, LEDs, speaker, backlight, orientation, Ethernet / Wi‑Fi / BT / USB keyboard.
class P2DemoPage extends StatefulWidget {
  const P2DemoPage({
    super.key,
    this.deviceSnReader = const DeviceSnReader(),
    this.modbusClient,
    this.ledController,
    this.audioController,
    this.backlightController,
    this.orientationController,
    this.ethernetController,
    this.wifiController,
    this.httpClientController,
    this.bluetoothController,
  });

  final DeviceSnReader deviceSnReader;
  final ModbusRtuClient? modbusClient;
  final GpioLedController? ledController;
  final MediaAudioController? audioController;
  final BacklightController? backlightController;
  final DisplayOrientationController? orientationController;
  final EthernetController? ethernetController;
  final WifiController? wifiController;
  final HttpClientController? httpClientController;
  final BluetoothController? bluetoothController;

  @override
  State<P2DemoPage> createState() => _P2DemoPageState();
}

class _P2DemoPageState extends State<P2DemoPage> {
  late final ModbusRtuClient _modbus;
  late final GpioLedController _leds;
  late final MediaAudioController _audio;
  late final BacklightController _backlight;
  late final DisplayOrientationController _orientation;
  late final EthernetController _ethernet;
  late final WifiController _wifi;
  late final HttpClientController _http;
  late final BluetoothController _bluetooth;
  bool _networkSectionsReady = false;

  String _deviceSn = kUnavailableDisplay;
  String _gunheadSn = kUnavailableDisplay;
  String _firmwareVersion = kUnavailableDisplay;
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;

  String _motorTemperature = kUnavailableDisplay;
  String _motorDriverTemperature = kUnavailableDisplay;
  String _protectiveMirrorTemperature = kUnavailableDisplay;
  String _collimatorTemperature = kUnavailableDisplay;

  final Map<LedColor, IndicatorMode> _ledModes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };

  bool _audioPlaying = false;
  double _volumePercent = 80;
  double _brightnessPercent = 80;
  DisplayOrientationMode _orientationMode = DisplayOrientationMode.landscape;

  StreamSubscription<bool>? _playingSub;

  // Brightness: latest-wins coalesce (same idea as AudioManager / backlight HAL).
  bool _brightnessBusy = false;
  int? _queuedBrightness;
  bool _listScrolling = false;

  @override
  void initState() {
    super.initState();
    _modbus = widget.modbusClient ?? ModbusRtuClient();
    _leds = widget.ledController ?? GpioLedController();
    _audio = widget.audioController ?? LinuxMediaAudioController();
    _backlight = widget.backlightController ?? LinuxSysfsBacklight();
    _orientation =
        widget.orientationController ?? LinuxFlutterPiOrientation();
    _ethernet = widget.ethernetController ?? LinuxEthernetController();
    _wifi = widget.wifiController ?? LinuxWpaWifiController();
    _http = widget.httpClientController ?? LinuxHttpClientController();
    _bluetooth = widget.bluetoothController ?? LinuxBluezBluetoothController();
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

    final sn = await widget.deviceSnReader.read();
    if (!mounted) {
      return;
    }
    setState(() => _deviceSn = sn);

    final info = await _modbus.readDeviceInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _gunheadSn = info.gunheadSn;
      _firmwareVersion = info.firmwareVersion;
      _laserVersion = info.laserVersion;
      _wireFeederVersion = info.wireFeederVersion;
    });

    final temps = await _modbus.readAlarmTemperatures();
    if (!mounted) {
      return;
    }
    setState(() {
      _motorTemperature = temps.motorTemperature;
      _motorDriverTemperature = temps.motorDriverTemperature;
      _protectiveMirrorTemperature = temps.protectiveMirrorTemperature;
      _collimatorTemperature = temps.collimatorTemperature;
    });

    // P2.1 platform I/O — after Modbus so first paint already happened.
    try {
      final vol = await _audio.getVolumePercent();
      final bri = await _backlight.getBrightnessPercent();
      final ori = await _orientation.getPreferred();
      if (!mounted) {
        return;
      }
      setState(() {
        _volumePercent = vol.toDouble();
        _brightnessPercent = bri.toDouble();
        _orientationMode = ori;
      });
    } catch (_) {
      // Non-fatal: sliders keep defaults.
    }
  }

  Future<void> _onLedMode(LedColor color, IndicatorMode mode) async {
    setState(() => _ledModes[color] = mode);
    await _leds.setMode(color, mode);
  }

  Future<void> _toggleAudio() async {
    if (_audio.isPlaying || _audioPlaying) {
      await _audio.stop();
      return;
    }
    await _audio.playAsset(MediaAudioController.shanghaiTanAsset);
  }

  /// Slider paint is local; hardware gets latest-wins apply (OS-style).
  void _onVolumeUi(double value) {
    _volumePercent = value;
    unawaited(_audio.setVolumePercent(value.round()));
  }

  void _onBrightnessUi(double value) {
    _brightnessPercent = value;
    _queuedBrightness = value.round();
    unawaited(_drainBrightness());
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

  Future<void> _onOrientation(DisplayOrientationMode mode) async {
    setState(() => _orientationMode = mode);
    await _orientation.setPreferred(mode);
  }

  @override
  void dispose() {
    unawaited(_playingSub?.cancel() ?? Future<void>.value());
    final bri = _queuedBrightness;
    if (bri != null) {
      unawaited(_backlight.setBrightnessPercent(bri));
    }
    unawaited(_audio.dispose());
    unawaited(_backlight.dispose());
    unawaited(_orientation.dispose());
    unawaited(_ethernet.dispose());
    unawaited(_wifi.dispose());
    unawaited(_http.dispose());
    unawaited(_bluetooth.dispose());
    unawaited(_leds.dispose());
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
            const SizedBox(height: 16),
            _InfoRow(label: 'Device SN', value: _deviceSn),
            _InfoRow(label: 'Gunhead SN', value: _gunheadSn),
            _InfoRow(label: 'Firmware Version', value: _firmwareVersion),
            _InfoRow(label: 'Laser Version', value: _laserVersion),
            _InfoRow(label: 'Wire Feeder Version', value: _wireFeederVersion),
            const SizedBox(height: 32),
            const Text(
              'Alarm Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Motor Temperature', value: _motorTemperature),
            _InfoRow(
              label: 'Motor Driver Temperature',
              value: _motorDriverTemperature,
            ),
            _InfoRow(
              label: 'Protective Mirror Temperature',
              value: _protectiveMirrorTemperature,
            ),
            _InfoRow(
              label: 'Collimator Temperature',
              value: _collimatorTemperature,
            ),
            const SizedBox(height: 32),
            const Text(
              'RGB LED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pins R/Y/G YNHAPI ${GpioLedConfig.redYnhApi}/'
              '${GpioLedConfig.yellowYnhApi}/${GpioLedConfig.greenYnhApi} → '
              'linux ${GpioLedConfig.redLinuxGpio}/'
              '${GpioLedConfig.yellowLinuxGpio}/${GpioLedConfig.greenLinuxGpio}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 16),
            for (final color in LedColor.values)
              _LedModeRow(
                color: color,
                selected: _ledModes[color]!,
                onSelected: (mode) => unawaited(_onLedMode(color, mode)),
              ),
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
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
            const SizedBox(height: 24),
            const Text(
              'Orientation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Applies via HMI restart (flutter-pi -o)',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 12),
            SegmentedButton<DisplayOrientationMode>(
              segments: const [
                ButtonSegment(
                  value: DisplayOrientationMode.portrait,
                  label: Text('Portrait'),
                ),
                ButtonSegment(
                  value: DisplayOrientationMode.landscape,
                  label: Text('Landscape'),
                ),
              ],
              selected: {_orientationMode},
              onSelectionChanged: (set) {
                if (set.isEmpty) {
                  return;
                }
                unawaited(_onOrientation(set.first));
              },
            ),
            if (_networkSectionsReady) ...[
              const SizedBox(height: 32),
              EthernetDemoSection(controller: _ethernet),
              const SizedBox(height: 32),
              const KeyboardDemoSection(),
              const SizedBox(height: 32),
              WifiDemoSection(controller: _wifi),
              const SizedBox(height: 32),
              HttpDemoSection(controller: _http),
              const SizedBox(height: 32),
              BluetoothDemoSection(controller: _bluetooth),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 22),
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
  });

  final String label;
  final double value;
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
    _value = widget.value.clamp(0, 100);
  }

  @override
  void didUpdateWidget(covariant _PercentSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from parent (e.g. post-frame hardware read) only when not dragging.
    if (!_dragging && (oldWidget.value - widget.value).abs() > 0.01) {
      _value = widget.value.clamp(0, 100);
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
          min: 0,
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

class _LedModeRow extends StatelessWidget {
  const _LedModeRow({
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final LedColor color;
  final IndicatorMode selected;
  final ValueChanged<IndicatorMode> onSelected;

  String get _title {
    switch (color) {
      case LedColor.red:
        return 'Red';
      case LedColor.yellow:
        return 'Yellow';
      case LedColor.green:
        return 'Green';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 8),
          SegmentedButton<IndicatorMode>(
            segments: const [
              ButtonSegment(value: IndicatorMode.steadyOn, label: Text('Steady')),
              ButtonSegment(value: IndicatorMode.blink, label: Text('Blink')),
              ButtonSegment(value: IndicatorMode.off, label: Text('Off')),
            ],
            selected: {selected},
            onSelectionChanged: (set) {
              if (set.isEmpty) {
                return;
              }
              onSelected(set.first);
            },
          ),
        ],
      ),
    );
  }
}
