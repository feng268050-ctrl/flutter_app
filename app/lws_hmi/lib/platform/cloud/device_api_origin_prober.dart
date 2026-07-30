import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';

/// Concurrent reachability probe for Worker API candidates (lws-ui
/// `DeviceApiOriginProber` parity): first success wins and cancels waiting.
final class DeviceApiOriginProber {
  DeviceApiOriginProber({
    required this.http,
    this.timeout = const Duration(seconds: 5),
  });

  final HttpClientController http;
  final Duration timeout;

  Uri? _pinned;
  int _generation = 0;

  Uri? get pinnedBase => _pinned;

  void clearPin() {
    _pinned = null;
  }

  /// Probe [tier] candidates concurrently; returns pinned base or null.
  Future<Uri?> probe(CloudEnvironmentTier tier) async {
    final generation = ++_generation;
    final candidates = DeviceApiOriginConfig.orderedCandidateBases(tier);
    if (candidates.isEmpty) {
      debugPrint('api-origin: no candidates for $tier');
      return null;
    }
    if (candidates.length == 1) {
      final only = candidates.first;
      final ok = await _probeOne(only);
      if (generation != _generation) {
        return _pinned;
      }
      if (ok) {
        _pinned = DeviceApiOriginConfig.stripTrailingSlash(only);
        debugPrint('api-origin: pinned $_pinned');
        return _pinned;
      }
      return null;
    }

    final completer = Completer<Uri?>();
    var remaining = candidates.length;
    var won = false;

    for (final base in candidates) {
      unawaited(() async {
        final ok = await _probeOne(base);
        if (generation != _generation) {
          return;
        }
        if (ok && !won) {
          won = true;
          _pinned = DeviceApiOriginConfig.stripTrailingSlash(base);
          debugPrint('api-origin: pinned $_pinned');
          if (!completer.isCompleted) {
            completer.complete(_pinned);
          }
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }());
    }

    // Slightly above per-probe timeout (lws-ui INVOKE_ANY_TIMEOUT_SEC = 6).
    return completer.future.timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => won ? _pinned : null,
    );
  }

  Future<bool> _probeOne(Uri base) async {
    try {
      final url = DeviceApiOriginConfig.rootProbeUri(base);
      final result = await http.request(
        method: 'GET',
        url: url,
        maxBodyBytes: 256,
        timeout: timeout,
      );
      // Any HTTP response (even 4xx) means the origin is reachable (lws-ui).
      return result.statusCode != null && result.statusCode! > 0;
    } catch (e) {
      debugPrint('api-origin: probe failed $base: $e');
      return false;
    }
  }
}
