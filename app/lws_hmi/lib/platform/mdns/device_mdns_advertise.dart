import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// DNS-SD advertise via `avahi-publish-service` (`_lws-device._tcp`, port 5580).
final class DeviceMdnsAdvertise {
  DeviceMdnsAdvertise({
    this.serviceType = '_lws-device._tcp',
    this.port = 5580,
  });

  final String serviceType;
  final int port;

  Process? _process;
  bool get isAdvertising => _process != null;

  Future<bool> publish({
    required String sn,
    required String model,
    required String systemVersion,
    String apiVer = '1',
    String connectProto = 'http',
  }) async {
    await withdraw();
    final instance = sn.trim().isEmpty ? 'lws-hmi' : sn.trim();
    final args = <String>[
      '-s',
      instance,
      serviceType,
      '$port',
      'sn=${sn.trim()}',
      'model=${model.trim()}',
      'system_version=${systemVersion.trim()}',
      'api_ver=$apiVer',
      'connect_proto=$connectProto',
    ];
    try {
      final proc = await Process.start('avahi-publish-service', args);
      _process = proc;
      unawaited(proc.exitCode.then((code) {
        if (identical(_process, proc)) {
          _process = null;
        }
        lwsTrace('mdns: avahi-publish exited $code');
      }));
      lwsTrace('mdns: advertising $instance $serviceType:$port');
      return true;
    } catch (e) {
      debugPrint('mdns: avahi-publish-service failed: $e');
      _process = null;
      return false;
    }
  }

  Future<void> withdraw() async {
    final proc = _process;
    _process = null;
    if (proc == null) {
      return;
    }
    try {
      proc.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }
}
